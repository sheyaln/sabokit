# State migrations for OIDC apps previously using ./modules/app.
# The old module used count conditionals (provider_type == "oauth2") and
# oauth2-prefixed resource names. These moved blocks handle both the count
# removal ([0] → bare) and the oauth2 → oidc rename.

moved {
  from = authentik_provider_oauth2.provider[0]
  to   = authentik_provider_oauth2.provider
}

moved {
  from = random_uuid.oauth_client_id[0]
  to   = random_uuid.oidc_client_id
}

moved {
  from = random_password.oauth_client_secret[0]
  to   = random_password.oidc_client_secret
}

moved {
  from = scaleway_secret_version.oauth_credentials[0]
  to   = scaleway_secret_version.oidc_credentials
}
