# Per-env variables. Everything that is a *configuration choice* lives in
# config.tf (committable). This file only carries values that are runtime
# credentials and cannot live on disk:
#
#   - scaleway_access_key / scaleway_secret_key — supplied via env vars
#     (SCW_ACCESS_KEY / SCW_SECRET_KEY or TF_VAR_scaleway_access_key /
#     TF_VAR_scaleway_secret_key). _lib.sh re-exports them as SCW_* so the
#     provider sees a single credential source.
#   - authentik_admin_token — populated by configure.sh after up.sh creates
#     the bootstrap admin secret. Empty during the first-phase apply.

variable "scaleway_access_key" {
  type      = string
  sensitive = true
}

variable "scaleway_secret_key" {
  type      = string
  sensitive = true
}

variable "authentik_admin_token" {
  description = "Authentik admin API token. Empty during the first-phase apply (when Authentik doesn't exist yet); configure.sh fetches it from the bootstrap admin secret and re-exports as TF_VAR_authentik_admin_token before the second phase."
  type        = string
  sensitive   = true
  default     = ""
}
