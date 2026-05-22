
# Secrets Module - Outputs


output "secret_ids" {
  description = "Map of secret names to their Scaleway secret IDs"
  value = {
    for name, secret in scaleway_secret.this : name => secret.id
  }
}

output "secret_paths" {
  description = "Map of secret names to their paths (for Ansible lookups)"
  value = {
    for name, config in local.all_secrets : name => config.path
  }
}

output "secrets" {
  description = "Full secret resources for reference"
  value       = scaleway_secret.this
}

output "manual_secrets_needed" {
  description = "List of secrets that need manual upload to Scaleway (not auto-generated, no predefined value)"
  value = [
    for name, secret in local.manual_secrets : {
      name        = name
      description = secret.description
      path        = secret.path
      type        = secret.type
    }
  ]
}

output "valued_secrets" {
  description = "List of secrets with predefined values from config"
  value = [
    for name, secret in local.valued_secrets : {
      name        = name
      description = secret.description
      path        = secret.path
      type        = secret.type
    }
  ]
}
