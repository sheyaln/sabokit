# State migrations for SAML apps moving from ./modules/app to ./modules/saml-app.
# The old module used count conditionals (provider_type == "saml") which are now
# removed since this module is SAML-only. These moved blocks map [0]-indexed
# state addresses to their new non-indexed addresses.

moved {
  from = authentik_provider_saml.provider[0]
  to   = authentik_provider_saml.provider
}

moved {
  from = authentik_property_mapping_provider_saml.email[0]
  to   = authentik_property_mapping_provider_saml.email
}

moved {
  from = authentik_property_mapping_provider_saml.first_name[0]
  to   = authentik_property_mapping_provider_saml.first_name
}

moved {
  from = authentik_property_mapping_provider_saml.last_name[0]
  to   = authentik_property_mapping_provider_saml.last_name
}

moved {
  from = authentik_property_mapping_provider_saml.display_name[0]
  to   = authentik_property_mapping_provider_saml.display_name
}

moved {
  from = authentik_property_mapping_provider_saml.username[0]
  to   = authentik_property_mapping_provider_saml.username
}

moved {
  from = scaleway_secret_version.saml_credentials[0]
  to   = scaleway_secret_version.saml_credentials
}
