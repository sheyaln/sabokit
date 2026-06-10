# Surfaced for the deploy scripts and the downstream layers' apply path. The
# other layers self-discover infra's resources by name (the data-source
# contract), so these outputs are for the scripts, not for TF wiring.

output "compute" {
  description = "Compute hosts incl. public/private IPs. scripts/lib.sh builds the Ansible inventory from this."
  value       = module.infra.compute
}

output "domains" {
  value = module.infra.domains
}

output "spf_include" {
  description = "TEM SPF include directive. Compose into an SPF TXT record via infra.yml custom_dns_records."
  value       = module.infra.spf_include
}

output "host_services" {
  description = "Per-host watcher instances (diun/autoheal/wazuh-agent) the host-services play deploys."
  value       = module.infra.host_services
  sensitive   = true
}

output "identity_bootstrap" {
  description = "Secret-ID map the authentik-server Ansible role consumes. Passed to the identity deploy as -e identity_bootstrap=$(terraform output -json identity_bootstrap)."
  value       = module.infra.identity_bootstrap
  sensitive   = true
}

output "authentik_admin_secret_id" {
  description = "Scaleway secret holding {username,email,password,api_token}. The deploy scripts fetch api_token -> TF_VAR_authentik_admin_token for the identity/operations/application layers."
  value       = module.infra.authentik_admin_secret_id
  sensitive   = true
}

output "infra_email" {
  description = "Ops contact email, surfaced so the deploy scripts pass it to the traefik role for the Let's Encrypt ACME registration."
  value       = local.env.infra_email
}
