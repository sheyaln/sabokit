# Postiz app secrets: JWT signing key + OIDC bag + temporal-postgres bootstrap
# password + every social-platform credential the consumer supplied. Stored as
# one key_value Scaleway secret so the Ansible role does a single lookup.

resource "random_password" "jwt_secret" {
  count   = var.enabled ? 1 : 0
  length  = 64
  special = false
}

# Temporal's bundled postgres needs a bootstrap password. Stays in-stack with
# the temporal containers; never reaches Scaleway RDB.
resource "random_password" "temporal_pg" {
  count   = var.enabled ? 1 : 0
  length  = 32
  special = false
}

resource "scaleway_secret" "app" {
  count = var.enabled ? 1 : 0

  name        = "${local.slug}-app-secrets"
  description = "Postiz application secrets (JWT, OIDC, temporal-pg bootstrap, social-platform OAuth bag)"
  tags        = ["automated", local.slug]
  type        = "key_value"
}

resource "scaleway_secret_version" "app" {
  count = var.enabled ? 1 : 0

  secret_id = scaleway_secret.app[0].id
  data = jsonencode(merge(
    {
      JWT_SECRET = random_password.jwt_secret[0].result

      # Public URLs Postiz uses for both server-side links + browser-rendered
      # absolute paths. Must match the hostname Traefik fronts.
      MAIN_URL                = local.app_url
      FRONTEND_URL            = local.app_url
      NEXT_PUBLIC_BACKEND_URL = "${local.app_url}/api"

      # Internal API URL inside the container (the NestJS API binds to :3000
      # while the NextJS frontend serves :5000 — same process, two ports).
      BACKEND_INTERNAL_URL = "http://localhost:3000"

      # OIDC (Authentik). Postiz reads these via its generic-OAuth path.
      POSTIZ_GENERIC_OAUTH                  = "true"
      POSTIZ_OAUTH_URL                      = "https://${var.base.authentik.gateway_domain}"
      POSTIZ_OAUTH_AUTH_URL                 = "https://${var.base.authentik.gateway_domain}/application/o/authorize/"
      POSTIZ_OAUTH_TOKEN_URL                = "https://${var.base.authentik.gateway_domain}/application/o/token/"
      POSTIZ_OAUTH_USERINFO_URL             = "https://${var.base.authentik.gateway_domain}/application/o/userinfo/"
      POSTIZ_OAUTH_CLIENT_ID                = module.authentik[0].client_id
      POSTIZ_OAUTH_CLIENT_SECRET            = module.authentik[0].client_secret
      POSTIZ_OAUTH_SCOPE                    = "openid profile email"
      NEXT_PUBLIC_POSTIZ_OAUTH_DISPLAY_NAME = "Authentik"

      # Temporal's bundled postgres bootstrap creds.
      TEMPORAL_POSTGRES_USER     = "temporal"
      TEMPORAL_POSTGRES_PASSWORD = random_password.temporal_pg[0].result

      # From-address only. SMTP host/port/user/password come from the
      # platform-wide smtp-config secret looked up by the Ansible role.
      EMAIL_FROM_ADDRESS = var.smtp_from_email
    },
    # Flatten social_platform_credentials: { x = { X_API_KEY = "...", ... }, ... }
    # becomes top-level keys in the secret bag. Postiz reads each env var
    # directly; the per-platform grouping is purely an organizational input.
    {
      for env_var, value in merge([
        for platform, vars in var.social_platform_credentials : vars
      ]...) : env_var => value
    },
  ))
}
