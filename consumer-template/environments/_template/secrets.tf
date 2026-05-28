# Scaleway Secret Manager references.
#
# Bag IDs (UUIDs) are committable — they identify the bag, not its payload.
# The payload itself stays in Scaleway and never enters the repo.
#
# Use this file when a secret needs to flow through Terraform — e.g. an API
# key consumed by a downstream
# provider, or a credential surfaced as an env var to a sibling resource.
# For values consumed only by app bundles (e.g. smtp_secret_name), pass the
# bag NAME through `local.config.*` and let the bundle resolve it via its
# own ansible role at deploy time. No data source needed here.
#
# Pattern when a data source IS needed:
#
#   data "scaleway_secret_version" "smtp_config" {
#     secret_id = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"  # bag UUID — committable
#     revision  = "latest"
#   }
#
#   # consumed elsewhere as:
#   #   jsondecode(data.scaleway_secret_version.smtp_config.data).smtp_password
#
# Default: empty — nothing in the bundled stack module requires a consumer-side
# data source on first deploy.
