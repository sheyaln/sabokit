# Jitsi secrets bag. Holds:
#   - JWT_APP_SECRET   : signing key shared between the OIDC adapter (issuer)
#                        and prosody (verifier). Rotating this invalidates
#                        every in-flight meeting JWT; users have to re-auth.
#   - JICOFO_AUTH_PASSWORD, JVB_AUTH_PASSWORD : XMPP creds for the internal
#                        service accounts prosody uses to authenticate the
#                        focus component and the video bridge.
#   - JIBRI_XMPP_PASSWORD, JIBRI_RECORDER_PASSWORD : reserved for the optional
#                        Jibri recording component. Generated up-front so a
#                        future Jibri rollout doesn't require re-rotating
#                        every other password.
#   - OIDC_*           : pulled from the oidc-app module's output so the
#                        Ansible role can render env files from one secret.
#
# ignore_changes on the version is intentional: rotating any of these via a
# fresh secret_version forces an apply-time replacement; for Jitsi that means
# every active meeting drops. Rotate by manually creating a new version, then
# restarting containers, not by churning Terraform state.

resource "random_password" "jwt_app_secret" {
  count   = var.enabled ? 1 : 0
  length  = 48
  special = false
}

resource "random_password" "jicofo_auth" {
  count   = var.enabled ? 1 : 0
  length  = 32
  special = false
}

resource "random_password" "jvb_auth" {
  count   = var.enabled ? 1 : 0
  length  = 32
  special = false
}

resource "random_password" "jibri_xmpp" {
  count   = var.enabled ? 1 : 0
  length  = 32
  special = false
}

resource "random_password" "jibri_recorder" {
  count   = var.enabled ? 1 : 0
  length  = 32
  special = false
}

resource "scaleway_secret" "app" {
  count = var.enabled ? 1 : 0

  name        = "${local.slug}-app-secrets"
  description = "Jitsi application secrets (JWT signing key, XMPP component passwords, OIDC bag)."
  tags        = ["automated", local.slug]
  type        = "key_value"
}

resource "scaleway_secret_version" "app" {
  count = var.enabled ? 1 : 0

  secret_id = scaleway_secret.app[0].id
  data = jsonencode({
    JITSI_JWT_APP_SECRET          = random_password.jwt_app_secret[0].result
    JITSI_JICOFO_AUTH_PASSWORD    = random_password.jicofo_auth[0].result
    JITSI_JVB_AUTH_PASSWORD       = random_password.jvb_auth[0].result
    JITSI_JIBRI_XMPP_PASSWORD     = random_password.jibri_xmpp[0].result
    JITSI_JIBRI_RECORDER_PASSWORD = random_password.jibri_recorder[0].result

    JITSI_OIDC_CLIENT_ID     = module.authentik[0].client_id
    JITSI_OIDC_CLIENT_SECRET = module.authentik[0].client_secret
    JITSI_OIDC_DISCOVERY_URL = "https://${var.base.authentik.gateway_domain}/application/o/${local.application_slug}/.well-known/openid-configuration"
  })

  lifecycle {
    # Rotating any value here forces a new secret version on apply, which
    # restarts the stack and kicks every active meeting. Rotate out-of-band.
    ignore_changes = [data]
  }
}
