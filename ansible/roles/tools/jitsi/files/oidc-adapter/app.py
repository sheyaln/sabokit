"""
Jitsi OIDC Adapter - Generic OpenID Connect authentication for Jitsi Meet
Based on https://github.com/aadpM2hhdixoJm3u/jitsi-OIDC-adapter
Modified to use environment variables for Docker deployment
"""

import os
import datetime
import hashlib
import secrets
import logging
import base64

from flask import Flask, request, session, url_for, redirect
from authlib.integrations.flask_client import OAuth
from flask_session import Session
from werkzeug.middleware.proxy_fix import ProxyFix
import jwt
from jwt import PyJWTError
from urllib.parse import urljoin
import requests
from cryptography.hazmat.backends import default_backend
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric import rsa

# Configuration from environment variables
OIDC_CLIENT_ID = os.environ.get('OIDC_CLIENT_ID', '')
OIDC_CLIENT_SECRET = os.environ.get('OIDC_CLIENT_SECRET', '')
OIDC_DISCOVERY_URL = os.environ.get('OIDC_DISCOVERY_URL', '')
OIDC_SCOPE = os.environ.get('OIDC_SCOPE', 'openid email profile')

JITSI_BASE_URL = os.environ.get('JITSI_BASE_URL', 'https://meet.example.com')
JWT_APP_ID = os.environ.get('JWT_APP_ID', 'jitsi')
JWT_APP_SECRET = os.environ.get('JWT_APP_SECRET', '')
JWT_SUBJECT = os.environ.get('JWT_SUBJECT', 'meet.example.com')

LOG_LEVEL = os.environ.get('LOG_LEVEL', 'INFO')

# Setup logging
logging.basicConfig(
    level=getattr(logging, LOG_LEVEL.upper(), logging.INFO),
    format='%(asctime)s - %(levelname)s - %(message)s'
)

app = Flask(__name__)
app.secret_key = secrets.token_urlsafe(32)
app.wsgi_app = ProxyFix(app.wsgi_app, x_for=1, x_proto=1, x_host=1)

app.config['SESSION_TYPE'] = 'filesystem'
app.config['SESSION_FILE_DIR'] = '/app/flask_session'
app.config['SESSION_COOKIE_SECURE'] = True
app.config['SESSION_COOKIE_HTTPONLY'] = True
app.config['SESSION_COOKIE_SAMESITE'] = 'Lax'
Session(app)

oauth = OAuth(app)

def fetch_oidc_configuration():
    """Fetch OIDC configuration from discovery URL"""
    if not OIDC_DISCOVERY_URL:
        logging.error("OIDC_DISCOVERY_URL not configured")
        return None
    
    try:
        response = requests.get(OIDC_DISCOVERY_URL, timeout=10)
        response.raise_for_status()
        config = response.json()
        logging.info(f"OIDC configuration fetched from {OIDC_DISCOVERY_URL}")
        logging.debug(f"OIDC endpoints: auth={config.get('authorization_endpoint')}, token={config.get('token_endpoint')}")
        return config
    except Exception as e:
        logging.error(f"Failed to fetch OIDC configuration: {e}")
        return None

# Fetch OIDC config at startup
oidc_config = fetch_oidc_configuration()

if oidc_config:
    oauth.register(
        name='oidc',
        client_id=OIDC_CLIENT_ID,
        client_secret=OIDC_CLIENT_SECRET,
        authorize_url=oidc_config['authorization_endpoint'],
        access_token_url=oidc_config['token_endpoint'],
        jwks_uri=oidc_config['jwks_uri'],
        issuer=oidc_config['issuer'],
        client_kwargs={'scope': OIDC_SCOPE},
    )
    logging.info("OAuth client registered successfully")
else:
    logging.error("Failed to initialize OIDC client - discovery failed")

def get_jwks_keys(jwks_uri):
    """Fetch JWKS keys from the provider"""
    resp = requests.get(jwks_uri, timeout=10)
    return resp.json()

def jwks_to_pem(key_json):
    """Convert RSA key from JWK to PEM format"""
    public_num = rsa.RSAPublicNumbers(
        e=int(base64.urlsafe_b64decode(key_json['e'] + '==').hex(), 16),
        n=int(base64.urlsafe_b64decode(key_json['n'] + '==').hex(), 16)
    )
    public_key = public_num.public_key(default_backend())
    pem = public_key.public_bytes(
        encoding=serialization.Encoding.PEM,
        format=serialization.PublicFormat.SubjectPublicKeyInfo
    )
    return pem

def parse_id_token(id_token, jwks_uri):
    """Parse and validate the ID token"""
    jwks = get_jwks_keys(jwks_uri)
    header = jwt.get_unverified_header(id_token)
    
    rsa_key = None
    for key in jwks['keys']:
        if key.get('kid') == header.get('kid'):
            rsa_key = jwks_to_pem(key)
            break
    
    if not rsa_key:
        logging.error("RSA key not found for token decoding")
        return None
    
    try:
        decoded = jwt.decode(
            id_token,
            rsa_key,
            algorithms=['RS256'],
            audience=OIDC_CLIENT_ID,
            issuer=oidc_config['issuer']
        )
        logging.debug("ID token successfully decoded")
        return decoded
    except jwt.ExpiredSignatureError:
        logging.error("Token expired")
    except jwt.InvalidTokenError as e:
        logging.error(f"Invalid token: {e}")
    except PyJWTError as e:
        logging.error(f"JWT Error: {e}")
    except Exception as e:
        logging.error(f"Unexpected error decoding token: {e}")
    
    return None

def get_gravatar_url(email):
    """Generate Gravatar URL from email"""
    if not email:
        return None
    email = email.strip().lower()
    email_hash = hashlib.sha256(email.encode('utf-8')).hexdigest()
    return f"https://www.gravatar.com/avatar/{email_hash}"

@app.route('/health')
@app.route('/oidc/health')
def health():
    """Health check endpoint"""
    return 'OK', 200

@app.route('/oidc/auth')
def login():
    """Initiate OIDC authentication flow"""
    if not oidc_config:
        return 'OIDC not configured', 500
    
    redirect_uri = urljoin(JITSI_BASE_URL, '/oidc/redirect')
    logging.debug(f'Redirect URI: {redirect_uri}')
    
    result = oauth.oidc.create_authorization_url(redirect_uri=redirect_uri)
    auth_url = result['url']
    
    # Get room name from query parameter
    room_name = request.args.get('roomname', request.args.get('room', 'lobby'))
    
    # Store session data
    session['room_name'] = room_name
    session['oauth_state'] = result['state']
    session['oauth_nonce'] = result.get('nonce')
    
    logging.info(f'Starting auth for room: {room_name}')
    logging.debug(f'Auth URL: {auth_url}')
    
    return redirect(auth_url)

@app.route('/oidc/redirect')
def oauth_callback():
    """Handle OIDC callback after authentication"""
    try:
        code = request.args.get('code')
        if not code:
            logging.error("Authorization code not found")
            return "Authorization code not found", 400
        
        # Exchange code for tokens
        token_url = oidc_config['token_endpoint']
        redirect_uri = urljoin(JITSI_BASE_URL, '/oidc/redirect')
        
        data = {
            'grant_type': 'authorization_code',
            'code': code,
            'redirect_uri': redirect_uri,
            'client_id': OIDC_CLIENT_ID,
            'client_secret': OIDC_CLIENT_SECRET
        }
        
        response = requests.post(token_url, data=data, timeout=10)
        
        if response.status_code != 200:
            logging.error(f"Token exchange failed: {response.status_code} - {response.text}")
            return "Token exchange failed", 500
        
        token_data = response.json()
        
        if 'id_token' not in token_data:
            logging.error("ID token not in response")
            return "ID token not found", 500
        
        # Parse ID token
        id_token = parse_id_token(token_data['id_token'], oidc_config['jwks_uri'])
        
        if not id_token:
            return "Failed to parse ID token", 500
        
        # Verify nonce if present
        stored_nonce = session.pop('oauth_nonce', None)
        if stored_nonce and id_token.get('nonce') != stored_nonce:
            logging.error("Nonce mismatch")
            return "Nonce mismatch", 400
        
        # Extract user info - try multiple claim names for compatibility
        name = (id_token.get('name') or 
                id_token.get('displayName') or 
                id_token.get('preferred_username') or 
                'User')
        email = id_token.get('email', '')
        
        avatar_url = get_gravatar_url(email) if email else ''
        
        session['user_info'] = {
            'id': id_token.get('sub', ''),
            'name': name,
            'email': email,
            'avatar': avatar_url
        }
        
        logging.info(f"User authenticated: {name} ({email})")
        return redirect(url_for('tokenize'))
        
    except Exception as e:
        logging.error(f"Error in OIDC callback: {e}")
        return f"Authentication error: {e}", 500

@app.route('/oidc/tokenize')
def tokenize():
    """Generate Jitsi JWT token and redirect to meeting"""
    user_info = session.get('user_info')
    if not user_info:
        logging.error("User not logged in - no session")
        return redirect(url_for('login'))
    
    room_name = session.get('room_name', 'lobby')
    
    # Build JWT payload for Jitsi
    jwt_payload = {
        "context": {
            "user": {
                "id": user_info.get('id', ''),
                "avatar": user_info.get('avatar', ''),
                "name": user_info['name'],
                "email": user_info.get('email', ''),
                "affiliation": "owner",
            }
        },
        "aud": JWT_APP_ID,
        "iss": JWT_APP_ID,
        "sub": JWT_SUBJECT,
        "room": room_name,
        "iat": datetime.datetime.now(datetime.timezone.utc),
        "nbf": datetime.datetime.now(datetime.timezone.utc),
        "exp": datetime.datetime.now(datetime.timezone.utc) + datetime.timedelta(hours=3)
    }
    
    encoded_jwt = jwt.encode(jwt_payload, JWT_APP_SECRET, algorithm='HS256')
    
    # Redirect to meeting room with JWT
    final_url = f"{JITSI_BASE_URL}/{room_name}?jwt={encoded_jwt}#config.prejoinPageEnabled=false"
    logging.info(f"Redirecting authenticated user to: {JITSI_BASE_URL}/{room_name}")
    
    return redirect(final_url)

if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=8000)
