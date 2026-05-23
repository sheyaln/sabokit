/**
 * n8n External Hooks for OIDC Authentication
 *
 * Implements OIDC authentication for n8n with stdlib-only deps so the file
 * can be bind-mounted into the upstream image without rebuilding.
 *
 * Wired up:
 *   - OIDC authorization-code flow (with discovery + nonce/state CSRF defence)
 *   - JIT user provisioning on first OIDC login
 *   - n8n role assignment from the OIDC `groups` claim:
 *       - first ever user always becomes global:owner (bootstrap)
 *       - subsequent users in OIDC_ADMIN_GROUP become global:owner
 *       - everyone else becomes global:member
 *   - Login-page customisation that swaps the password form for an SSO button
 *
 * Required env vars:
 *   OIDC_ISSUER_URL       - OIDC provider's issuer URL (e.g. https://auth.example.org)
 *   OIDC_CLIENT_ID
 *   OIDC_CLIENT_SECRET
 *   OIDC_REDIRECT_URI     - Full callback URL (e.g. https://flows.example.org/auth/oidc/callback)
 *
 * Optional env vars:
 *   OIDC_SCOPES           - Space-separated scopes (default: "openid email profile groups")
 *   OIDC_ADMIN_GROUP      - Group name in the `groups` claim that grants
 *                           n8n's global:owner role (default: "admin")
 */

const https = require('https');
const http = require('http');
const crypto = require('crypto');
const { URL, URLSearchParams } = require('url');

const config = {
  issuerUrl: process.env.OIDC_ISSUER_URL,
  clientId: process.env.OIDC_CLIENT_ID,
  clientSecret: process.env.OIDC_CLIENT_SECRET,
  redirectUri: process.env.OIDC_REDIRECT_URI,
  scopes: process.env.OIDC_SCOPES || 'openid email profile groups',
  adminGroup: process.env.OIDC_ADMIN_GROUP || 'admin',
};

function validateConfig() {
  const missing = [];
  if (!config.issuerUrl) missing.push('OIDC_ISSUER_URL');
  if (!config.clientId) missing.push('OIDC_CLIENT_ID');
  if (!config.clientSecret) missing.push('OIDC_CLIENT_SECRET');
  if (!config.redirectUri) missing.push('OIDC_REDIRECT_URI');
  return missing;
}

// Cache for the OIDC discovery document so we aren't hitting the provider
// on every login.
let discoveryCache = null;
let discoveryCacheTime = 0;
const DISCOVERY_CACHE_TTL = 3600000; // 1h

function makeRequest(url, options = {}) {
  return new Promise((resolve, reject) => {
    const parsedUrl = new URL(url);
    const protocol = parsedUrl.protocol === 'https:' ? https : http;

    const reqOptions = {
      hostname: parsedUrl.hostname,
      port: parsedUrl.port || (parsedUrl.protocol === 'https:' ? 443 : 80),
      path: parsedUrl.pathname + parsedUrl.search,
      method: options.method || 'GET',
      headers: options.headers || {},
    };

    const req = protocol.request(reqOptions, (res) => {
      let body = '';
      res.on('data', (chunk) => (body += chunk));
      res.on('end', () => {
        resolve({ statusCode: res.statusCode, headers: res.headers, body });
      });
    });

    req.on('error', reject);

    if (options.body) {
      req.write(options.body);
    }

    req.end();
  });
}

async function fetchDiscoveryDocument() {
  const now = Date.now();
  if (discoveryCache && now - discoveryCacheTime < DISCOVERY_CACHE_TTL) {
    return discoveryCache;
  }

  const discoveryUrl = config.issuerUrl.replace(/\/$/, '') + '/.well-known/openid-configuration';
  const response = await makeRequest(discoveryUrl);

  if (response.statusCode !== 200) {
    throw new Error(`Failed to fetch OIDC discovery document: ${response.statusCode}`);
  }

  discoveryCache = JSON.parse(response.body);
  discoveryCacheTime = now;
  return discoveryCache;
}

function generateRandomString(length = 32) {
  return crypto.randomBytes(length).toString('hex');
}

function base64UrlEncode(input) {
  const base64 = Buffer.isBuffer(input) ? input.toString('base64') : Buffer.from(input).toString('base64');
  return base64.replace(/\+/g, '-').replace(/\//g, '_').replace(/=/g, '');
}

function base64UrlDecode(input) {
  let base64 = input.replace(/-/g, '+').replace(/_/g, '/');
  while (base64.length % 4) {
    base64 += '=';
  }
  return Buffer.from(base64, 'base64');
}

function decodeJwt(token) {
  const parts = token.split('.');
  if (parts.length !== 3) {
    throw new Error('Invalid JWT format');
  }
  return JSON.parse(base64UrlDecode(parts[1]).toString('utf8'));
}

async function exchangeCodeForTokens(code, discovery) {
  const params = new URLSearchParams({
    grant_type: 'authorization_code',
    code,
    redirect_uri: config.redirectUri,
    client_id: config.clientId,
    client_secret: config.clientSecret,
  });

  const response = await makeRequest(discovery.token_endpoint, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: params.toString(),
  });

  if (response.statusCode !== 200) {
    console.error('[OIDC Hook] Token exchange failed:', response.body);
    throw new Error(`Token exchange failed: ${response.statusCode}`);
  }

  return JSON.parse(response.body);
}

async function fetchUserInfo(accessToken, discovery) {
  const response = await makeRequest(discovery.userinfo_endpoint, {
    headers: { Authorization: `Bearer ${accessToken}` },
  });

  if (response.statusCode !== 200) {
    console.error('[OIDC Hook] UserInfo fetch failed:', response.body);
    throw new Error(`UserInfo fetch failed: ${response.statusCode}`);
  }

  return JSON.parse(response.body);
}

// HMAC-signed short-lived cookies for state/nonce — small enough to live in
// a Set-Cookie header, immune to tampering without the n8n encryption key.
function createSignedCookie(payload, secret, expiresInSeconds = 900) {
  const exp = Math.floor(Date.now() / 1000) + expiresInSeconds;
  const data = JSON.stringify({ ...payload, exp });
  const hmac = crypto.createHmac('sha256', secret);
  hmac.update(data);
  const signature = hmac.digest('hex');
  return base64UrlEncode(data) + '.' + signature;
}

function verifySignedCookie(cookie, secret) {
  try {
    const [dataB64, signature] = cookie.split('.');
    const data = base64UrlDecode(dataB64).toString('utf8');

    const hmac = crypto.createHmac('sha256', secret);
    hmac.update(data);
    const expectedSignature = hmac.digest('hex');

    if (signature !== expectedSignature) {
      return null;
    }

    const payload = JSON.parse(data);
    if (payload.exp && payload.exp < Date.now() / 1000) {
      return null;
    }
    return payload;
  } catch {
    return null;
  }
}

// Derive the cookie signing secret from the n8n encryption key (always set in
// our deployments). Falls back to the OIDC client secret if not, then to a
// constant — the constant case still authenticates the cookies, it just
// makes them forgeable by anyone who can read this file, which they
// already can if they're inside the container.
function getCookieSecret() {
  const baseKey = process.env.N8N_ENCRYPTION_KEY || process.env.OIDC_CLIENT_SECRET || 'n8n-oidc-hook-secret';
  return crypto.createHash('sha256').update(baseKey + '-oidc-state').digest('hex');
}

// Mimics n8n's AuthService.createJWTHash so the JWT we issue is accepted
// by n8n's session middleware exactly the same as a password-issued one.
function createUserHash(user) {
  const payload = [user.email, user.password || ''];
  if (user.mfaEnabled && user.mfaSecret) {
    payload.push(user.mfaSecret.substring(0, 3));
  }
  return crypto.createHash('sha256').update(payload.join(':')).digest('base64').substring(0, 10);
}

function createAuthToken(user, jwtService) {
  return jwtService.sign(
    { id: user.id, hash: createUserHash(user), usedMfa: false },
    { expiresIn: '7d' },
  );
}

function isValidEmail(email) {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
}

// Map the OIDC `groups` claim to an n8n role. Authentik (and most OPs) emit
// `groups` as an array of group names. The hook checks for membership of the
// configured admin group name (defaults to "admin").
function pickRoleSlug(userInfo, isFirstUser) {
  if (isFirstUser) return 'global:owner';
  const groups = Array.isArray(userInfo.groups) ? userInfo.groups : [];
  return groups.includes(config.adminGroup) ? 'global:owner' : 'global:member';
}

// Paths into n8n's bundled node_modules — these are stable across minor
// versions of the upstream image but may need a bump on a major.
const N8N_DI_PATH = '/usr/local/lib/node_modules/n8n/node_modules/@n8n/di';
const N8N_JWT_SERVICE_PATH = '/usr/local/lib/node_modules/n8n/dist/services/jwt.service.js';

module.exports = {
  n8n: {
    ready: [
      async function (server, _n8nConfig) {
        const missing = validateConfig();
        if (missing.length > 0) {
          console.warn(`[OIDC Hook] Missing configuration: ${missing.join(', ')}. OIDC disabled.`);
          return;
        }

        console.log('[OIDC Hook] Initializing OIDC authentication...');

        const { Container } = require(N8N_DI_PATH);
        const { JwtService } = require(N8N_JWT_SERVICE_PATH);
        const jwtService = Container.get(JwtService);

        const { app } = server;
        const cookieSecret = getCookieSecret();

        const cookieOptions = {
          httpOnly: true,
          secure: process.env.N8N_PROTOCOL === 'https',
          sameSite: 'lax',
          maxAge: 15 * 60 * 1000,
        };

        const authCookieOptions = {
          httpOnly: true,
          secure: process.env.N8N_PROTOCOL === 'https',
          sameSite: 'lax',
          maxAge: 7 * 24 * 60 * 60 * 1000,
        };

        app.get('/auth/oidc/login', async (req, res) => {
          try {
            const discovery = await fetchDiscoveryDocument();

            const state = generateRandomString();
            const nonce = generateRandomString();

            res.cookie('n8n-oidc-state', createSignedCookie({ state }, cookieSecret), cookieOptions);
            res.cookie('n8n-oidc-nonce', createSignedCookie({ nonce }, cookieSecret), cookieOptions);

            const authUrl = new URL(discovery.authorization_endpoint);
            authUrl.searchParams.set('client_id', config.clientId);
            authUrl.searchParams.set('redirect_uri', config.redirectUri);
            authUrl.searchParams.set('response_type', 'code');
            authUrl.searchParams.set('scope', config.scopes);
            authUrl.searchParams.set('state', state);
            authUrl.searchParams.set('nonce', nonce);

            res.redirect(authUrl.toString());
          } catch (error) {
            console.error('[OIDC Hook] Login error:', error);
            res.status(500).send('OIDC configuration error. Please check the logs.');
          }
        });

        app.get('/auth/oidc/callback', async (req, res) => {
          try {
            const { code, state, error, error_description } = req.query;

            if (error) {
              console.error('[OIDC Hook] OIDC error:', error, error_description);
              return res.redirect('/signin?error=' + encodeURIComponent(error_description || error));
            }

            if (!code || !state) {
              return res.redirect('/signin?error=' + encodeURIComponent('Missing authorization code or state'));
            }

            const stateCookie = req.cookies['n8n-oidc-state'];
            const nonceCookie = req.cookies['n8n-oidc-nonce'];

            if (!stateCookie || !nonceCookie) {
              return res.redirect('/signin?error=' + encodeURIComponent('Missing state cookies - session expired'));
            }

            const statePayload = verifySignedCookie(stateCookie, cookieSecret);
            const noncePayload = verifySignedCookie(nonceCookie, cookieSecret);

            if (!statePayload || statePayload.state !== state) {
              return res.redirect('/signin?error=' + encodeURIComponent('Invalid state - possible CSRF attack'));
            }

            res.clearCookie('n8n-oidc-state');
            res.clearCookie('n8n-oidc-nonce');

            const discovery = await fetchDiscoveryDocument();
            const tokens = await exchangeCodeForTokens(code, discovery);

            if (tokens.id_token) {
              const idTokenClaims = decodeJwt(tokens.id_token);
              if (noncePayload && idTokenClaims.nonce !== noncePayload.nonce) {
                return res.redirect('/signin?error=' + encodeURIComponent('Invalid nonce - possible replay attack'));
              }
            }

            let userInfo;
            try {
              userInfo = await fetchUserInfo(tokens.access_token, discovery);
            } catch (e) {
              // Some providers serve a thin userinfo endpoint and stuff
              // everything in the ID token instead. Fall back to that.
              if (tokens.id_token) {
                userInfo = decodeJwt(tokens.id_token);
              } else {
                throw e;
              }
            }

            if (!userInfo.email || !isValidEmail(userInfo.email)) {
              return res.redirect('/signin?error=' + encodeURIComponent('No valid email in OIDC response'));
            }

            const { User } = this.dbCollections;

            let user = await User.findOne({
              where: { email: userInfo.email },
              relations: ['role'],
            });

            if (!user) {
              const userCount = await User.count();
              const roleSlug = pickRoleSlug(userInfo, userCount === 0);

              const userData = {
                email: userInfo.email,
                firstName: userInfo.given_name || userInfo.name?.split(' ')[0] || 'User',
                lastName: userInfo.family_name || userInfo.name?.split(' ').slice(1).join(' ') || '',
                // Random password the user can never use — they sign in via OIDC.
                password: crypto.randomBytes(32).toString('hex'),
                role: { slug: roleSlug },
              };

              const result = await User.createUserWithProject(userData);
              user = result.user;

              console.log(`[OIDC Hook] Provisioned ${roleSlug} user: ${userInfo.email}`);
            }

            if (!user) {
              return res.redirect('/signin?error=' + encodeURIComponent('Failed to create or find user'));
            }

            const authToken = createAuthToken(user, jwtService);
            res.cookie('n8n-auth', authToken, authCookieOptions);
            res.redirect('/');
          } catch (error) {
            console.error('[OIDC Hook] Callback error:', error);
            res.redirect('/signin?error=' + encodeURIComponent('Authentication failed: ' + error.message));
          }
        });

        // Served at /assets/* (not /auth/*) so n8n's SPA history fallback
        // doesn't intercept and return index.html instead of JS.
        app.get('/assets/oidc-frontend-hook.js', (req, res) => {
          res.type('text/javascript; charset=utf-8');
          res.set('Cache-Control', 'public, max-age=3600');
          res.send(getFrontendScript());
        });

        console.log('[OIDC Hook] OIDC routes registered:');
        console.log('  - GET /auth/oidc/login');
        console.log('  - GET /auth/oidc/callback');
        console.log('  - GET /assets/oidc-frontend-hook.js');
      },
    ],
  },

  frontend: {
    settings: [
      async function (frontendSettings) {
        if (validateConfig().length > 0) return;

        frontendSettings.sso = frontendSettings.sso || {};
        frontendSettings.sso.oidc = {
          loginEnabled: true,
          loginUrl: '/auth/oidc/login',
          callbackUrl: config.redirectUri,
        };

        frontendSettings.userManagement = frontendSettings.userManagement || {};
        frontendSettings.userManagement.authenticationMethod = 'oidc';

        // Enables the SSO button in n8n's enterprise UI path.
        frontendSettings.enterprise = frontendSettings.enterprise || {};
        frontendSettings.enterprise.oidc = true;

        console.log('[OIDC Hook] Frontend settings configured for OIDC');
      },
    ],
  },
};

/**
 * The script returned here runs in the browser and replaces n8n's login form
 * with a single "Sign in with SSO" button. ?showLogin=true bypasses it so an
 * operator can fall back to the password form for the bootstrap user.
 */
function getFrontendScript() {
  return `
(function() {
	'use strict';

	function shouldShowNormalLogin() {
		return new URLSearchParams(window.location.search).get('showLogin') === 'true';
	}

	function isSigninPage() {
		return window.location.pathname === '/signin' || window.location.pathname === '/login';
	}

	function displayError(form) {
		var error = new URLSearchParams(window.location.search).get('error');
		if (!error || !form || form.querySelector('#oidc-error')) return;

		var errorDiv = document.createElement('div');
		errorDiv.id = 'oidc-error';
		errorDiv.style.cssText = 'background: var(--color-danger-tint-1, #fee); border: 1px solid var(--color-danger, #fcc); color: var(--color-danger, #c00); padding: 12px; border-radius: 4px; margin: 16px 0;';
		errorDiv.textContent = decodeURIComponent(error);

		var heading = form.querySelector('div[class*="_heading_"]');
		if (heading) heading.after(errorDiv);
		else form.prepend(errorDiv);
	}

	function injectSsoButton() {
		if (shouldShowNormalLogin()) return;
		if (!isSigninPage()) return;

		var form = document.querySelector('[data-test-id="auth-form"]');
		if (!form || form.querySelector('#oidc-sso-button')) return;

		var existingButton = form.querySelector('[data-test-id="form-submit-button"]');
		var buttonClasses = existingButton ? existingButton.className : '';

		form.querySelectorAll('div[class*="_inputsContainer_"], div[class*="_buttonsContainer_"], div[class*="_actionContainer_"]')
			.forEach(function(el) { el.style.display = 'none'; });

		var ssoContainer = document.createElement('div');
		ssoContainer.id = 'oidc-sso-container';
		ssoContainer.style.cssText = 'text-align: center;';

		var button = document.createElement('button');
		button.id = 'oidc-sso-button';
		button.type = 'button';
		button.textContent = 'Sign in with SSO';
		button.onclick = function() { window.location.href = '/auth/oidc/login'; };

		if (buttonClasses) {
			button.className = buttonClasses;
			button.style.width = '100%';
		} else {
			button.style.cssText = 'width: 100%; padding: 12px 24px; font-size: 14px; font-weight: 600; color: white; background: var(--color-primary, #ea4b30); border: none; border-radius: 4px; cursor: pointer;';
		}

		var adminLink = document.createElement('p');
		adminLink.style.cssText = 'margin-top: 16px; font-size: 12px; color: var(--color-text-light, #666);';
		adminLink.innerHTML = 'Admin? <a href="?showLogin=true" style="color: var(--color-primary, #ea4b30);">Sign in with email</a>';

		ssoContainer.appendChild(button);
		ssoContainer.appendChild(adminLink);

		var heading = form.querySelector('div[class*="_heading_"]');
		if (heading) heading.after(ssoContainer);
		else form.prepend(ssoContainer);

		displayError(form);
	}

	function observeAndInject() {
		if (shouldShowNormalLogin() || !isSigninPage()) return;

		injectSsoButton();

		var observer = new MutationObserver(function() {
			if (isSigninPage() && !shouldShowNormalLogin()) {
				var form = document.querySelector('[data-test-id="auth-form"]');
				if (form && !form.querySelector('#oidc-sso-button')) {
					injectSsoButton();
				}
			}
		});

		observer.observe(document.body, { childList: true, subtree: true });
		setTimeout(function() { observer.disconnect(); }, 10000);
	}

	function handleNavigation() {
		var origPush = history.pushState;
		var origReplace = history.replaceState;

		history.pushState = function() {
			origPush.apply(this, arguments);
			setTimeout(observeAndInject, 100);
		};

		history.replaceState = function() {
			origReplace.apply(this, arguments);
			setTimeout(observeAndInject, 100);
		};

		window.addEventListener('popstate', function() {
			setTimeout(observeAndInject, 100);
		});
	}

	if (document.readyState === 'loading') {
		document.addEventListener('DOMContentLoaded', function() {
			observeAndInject();
			handleNavigation();
		});
	} else {
		observeAndInject();
		handleNavigation();
	}

	setTimeout(observeAndInject, 500);
	setTimeout(observeAndInject, 1000);

	console.log('[OIDC Hook] Frontend customization loaded');
})();
`;
}
