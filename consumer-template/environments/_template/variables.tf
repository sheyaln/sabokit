# SECRETS ONLY. Per-env NON-secret values (project_id, domains, sizes, network)
# live in `environments/env-values.yml` (committed) and are resolved by env.tf
# as `local.env.*`. Nothing non-secret is declared here.
#
# These come from the environment, never from a committed file:
#   SCW_ACCESS_KEY / SCW_SECRET_KEY  — drive the scaleway provider directly
#                                      (the provider block is empty on purpose)
#   TF_VAR_authentik_admin_token     — the authentik provider token
# Copy .envrc.example -> .envrc (gitignored) for local export, or set them in
# your shell. sabokit-cli passes them through to the terraform container.

# Declared (with empty defaults) so TF_VAR_scaleway_access_key/_secret_key bind
# without "undeclared variable" warnings and a bare `terraform apply` never
# prompts. The scaleway provider authenticates from SCW_* env regardless.
variable "scaleway_access_key" {
  type      = string
  sensitive = true
  default   = ""
}

variable "scaleway_secret_key" {
  type      = string
  sensitive = true
  default   = ""
}

variable "authentik_admin_token" {
  description = "Authentik admin API token. Empty on the first-phase apply (Authentik doesn't exist yet); the second-phase apply supplies it via TF_VAR_authentik_admin_token — sabokit-cli fetches it from the bootstrap admin secret, or export it yourself for a manual apply."
  type        = string
  sensitive   = true
  default     = ""
}
