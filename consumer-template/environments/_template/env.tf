# Per-env values, resolved from the keyed `environments/env-values.yml` by
# DIRECTORY NAME. This file is identical across env dirs — the directory you
# run terraform from selects its slice (environments/<env>/ -> the <env>: key).
#
# Works for `terraform apply` by hand and via sabokit-cli identically: no value
# is stored in the env dir, so a copied dir can never carry another env's
# project_id or domains. To add an env: add a top-level key to env-values.yml
# and create environments/<key>/ (or run `sabokit env add <key>`).
#
# Secrets are NOT here — SCW creds + authentik_admin_token come from the
# environment (.envrc / TF_VAR_*). See variables.tf.

locals {
  env_name = basename(abspath(path.root))

  # Non-secret defaults for rarely-varied keys; a slice's explicit values win.
  # Required keys (scaleway_project_id, base_domain, gateway_domain, infra_email)
  # are intentionally absent here so an incomplete slice fails loudly.
  _env_defaults = {
    scaleway_region        = "fr-par"
    scaleway_zone          = "fr-par-1"
    mgmt_domain            = ""
    private_network_subnet = "10.0.0.0/22"
    compute_instance_types = { tools = "DEV1-L", identity = "DEV1-M", management = "DEV1-M" }
    compute_disk_sizes     = { tools = 100, identity = 30, management = 60 }
  }

  env = merge(
    local._env_defaults,
    yamldecode(file("${path.module}/../env-values.yml"))[local.env_name],
  )
}
