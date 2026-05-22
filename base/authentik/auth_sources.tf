# Federated login sources. Each is gated by an enable_* toggle and pulls
# credentials from a Scaleway secret defined in data.tf. The flows submodule
# wires both into the source-authentication and source-enrollment flows.

resource "authentik_source_oauth" "google" {
  count = var.enable_google_social_login ? 1 : 0

  name                = "Google"
  slug                = "google"
  authentication_flow = module.flows.source_authentication_flow_uuid
  enrollment_flow     = module.flows.source_enrollment_flow_uuid

  provider_type   = "google"
  promoted        = true
  consumer_key    = local.google_oauth.client_id
  consumer_secret = local.google_oauth.client_secret

  access_token_url  = "https://oauth2.googleapis.com/token"
  authorization_url = "https://accounts.google.com/o/oauth2/v2/auth"
  oidc_jwks_url     = "https://www.googleapis.com/oauth2/v3/certs"
  profile_url       = "https://openidconnect.googleapis.com/v1/userinfo"

  user_matching_mode = "email_link"
  pkce               = "none"
  user_path_template = "users"

  depends_on = [
    module.flows.source_authentication_flow_uuid,
    module.flows.source_enrollment_flow_uuid,
  ]
}

resource "authentik_source_oauth" "apple" {
  count = var.enable_apple_social_login ? 1 : 0

  name                = "Apple ID"
  slug                = "apple"
  authentication_flow = module.flows.source_authentication_flow_uuid
  enrollment_flow     = module.flows.source_enrollment_flow_uuid

  provider_type = "apple"
  promoted      = true
  consumer_key  = local.apple_oauth.client_id
  # Apple's secret is a JWT that may have embedded literal "\n" sequences in
  # the secret store; restore the real newlines before handing it to Authentik.
  consumer_secret = replace(local.apple_oauth.client_secret, "\\n", "\n")

  user_matching_mode = "email_link"
  pkce               = "none"
  user_path_template = "users"

  depends_on = [
    module.flows.source_authentication_flow_uuid,
    module.flows.source_enrollment_flow_uuid,
  ]
}
