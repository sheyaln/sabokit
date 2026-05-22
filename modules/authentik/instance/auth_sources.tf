###########################
# Federated login sources #
###########################
resource "authentik_source_oauth" "google_social_login" {
  name                = "Google"
  slug                = "google"
  authentication_flow = module.flows.source_authentication_flow_uuid # Use new source auth flow
  enrollment_flow     = module.flows.source_enrollment_flow_uuid     # Use new passwordless enrollment

  provider_type   = "google"
  promoted        = true
  consumer_key    = local.google_oauth.client_id
  consumer_secret = local.google_oauth.client_secret

  access_token_url  = "https://oauth2.googleapis.com/token"
  authorization_url = "https://accounts.google.com/o/oauth2/v2/auth"
  oidc_jwks_url     = "https://www.googleapis.com/oauth2/v3/certs"
  profile_url       = "https://openidconnect.googleapis.com/v1/userinfo"

  # Using passwordless flows for social login

  user_matching_mode = "email_link"
  pkce               = "none"

  user_path_template = "users"

  depends_on = [
    module.flows.source_authentication_flow_uuid,
    module.flows.source_enrollment_flow_uuid
  ]
}

resource "authentik_source_oauth" "apple_social_login" {
  name                = "Apple ID"
  slug                = "apple"
  authentication_flow = module.flows.source_authentication_flow_uuid # Use new source auth flow
  enrollment_flow     = module.flows.source_enrollment_flow_uuid     # Use new passwordless enrollment

  provider_type   = "apple"
  promoted        = true
  consumer_key    = local.apple_oauth.client_id
  consumer_secret = replace(local.apple_oauth.client_secret, "\\n", "\n")

  # Using passwordless flows for social login

  user_matching_mode = "email_link"
  pkce               = "none"

  user_path_template = "users"

  depends_on = [
    module.flows.source_authentication_flow_uuid,
    module.flows.source_enrollment_flow_uuid
  ]
}
