
# Secrets Module - Scaleway Secret Manager

# Creates secrets in Scaleway Secret Manager from a configuration map.
# Supports auto-generated secrets (passwords) and manual secrets (API keys).
#
# Usage:
#   module "secrets" {
#     source  = "./modules/secrets"
#     secrets = yamldecode(file("config/secrets.yml")).secrets
#   }


locals {
  # Flatten all secrets from all categories into a single map
  # Key: secret name, Value: full secret config with category added
  all_secrets = var.secrets != null ? {
    for secret in flatten([
      for category, secrets in var.secrets : [
        for s in secrets : merge(s, {
          category = category
          tags     = concat([category], try(s.tags, []))
        })
      ]
    ]) : secret.name => secret
  } : {}

  # Secrets that should be auto-generated
  generated_secrets = {
    for name, secret in local.all_secrets : name => secret
    if try(secret.generate, false) == true
  }

  # Secrets with predefined values from config
  valued_secrets = {
    for name, secret in local.all_secrets : name => secret
    if try(secret.value, null) != null
  }

  # Secrets that need manual upload (not auto-generated, no predefined value)
  manual_secrets = {
    for name, secret in local.all_secrets : name => secret
    if try(secret.generate, false) == false && try(secret.value, null) == null
  }
}


# Secret Containers (all secrets)

# Creates the secret "container" in Scaleway Secret Manager.
# The actual value is either auto-generated or manually uploaded.

resource "scaleway_secret" "this" {
  for_each = local.all_secrets

  name        = each.key
  description = each.value.description
  type        = each.value.type
  path        = each.value.path
  tags        = each.value.tags
}


# Auto-Generated Secret Values

# For secrets with generate: true, create random passwords/keys

resource "random_password" "generated" {
  for_each = local.generated_secrets

  length  = try(each.value.length, 32)
  special = false

  # Prevent regenerating existing secrets when config changes
  lifecycle {
    ignore_changes = [length, special]
  }
}

# Store generated values in Scaleway
resource "scaleway_secret_version" "generated" {
  for_each = local.generated_secrets

  secret_id = scaleway_secret.this[each.key].id
  data      = random_password.generated[each.key].result

  depends_on = [scaleway_secret.this]

  lifecycle {
    # Don't update if the secret already has a version
    ignore_changes = [data]
  }
}


# Predefined Secret Values
#
# For secrets with value: defined in config, create versions from the config value
# Supports templating: {{ domains.management }}, {{ domains.tools }}, etc.

locals {
  # Template variables for secret values
  template_vars = {
    domains = try(var.project_config.domains, {})
    project = try(var.project_config.project, {})
  }
}

resource "scaleway_secret_version" "valued" {
  for_each = local.valued_secrets

  secret_id = scaleway_secret.this[each.key].id
  # Replace {{ key.subkey }} with values from project config
  data = base64encode(
    replace(
      replace(
        each.value.value,
        "{{ domains.management }}",
        try(var.project_config.domains.management, "")
      ),
      "{{ domains.tools }}",
      try(var.project_config.domains.tools, "")
    )
  )

  depends_on = [scaleway_secret.this]

  lifecycle {
    # Update when value changes in config
    create_before_destroy = true
  }
}
