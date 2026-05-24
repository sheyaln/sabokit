locals {
  slug = "backrest"

  # Every cloud resource is namespaced by qualified_slug so two instances
  # under the same base (e.g. backrest_mgmt + backrest_tools) cannot collide
  # on S3 bucket names, IAM application names, Authentik slugs, etc.
  qualified_slug = "${local.slug}-${var.instance_name}"

  authorized_groups = var.enabled ? (
    var.tier_cascade_enabled
    ? var.base.authentik.tier_cascade[var.tier_access_level]
    : merge(
      { (var.access_level) = var.base.authentik.groups[var.access_level] },
      var.extra_authorized_groups,
    )
  ) : {}

  app_url = "https://${var.hostname}"

  # Globally unique across all Scaleway customers. Namespaced by both the
  # consumer's secrets_namespace (e.g. "fc-prod") and the instance_name so
  # multiple instances under one consumer don't collide.
  bucket_name = "${var.base.scaleway.secrets_namespace}-${local.qualified_slug}"

  # Restic repo URI uses the bucket's regional s3 endpoint, with the scheme
  # stripped — restic expects `s3:host/bucket`, not `s3:https://host/bucket`.
  s3_endpoint_host = replace(var.base.scaleway.object_storage_endpoint, "/^https?:\\/\\//", "")
  restic_repo_uri  = var.enabled ? "s3:${local.s3_endpoint_host}/${module.bucket[0].name}" : ""
}
