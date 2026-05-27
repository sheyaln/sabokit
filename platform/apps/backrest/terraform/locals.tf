locals {
  slug = "backrest"

  # Every cloud resource is namespaced by qualified_slug so two instances
  # under the same base (e.g. backrest["management"] + backrest["tools"] under
  # the v3.4.0+ for_each fan-out) cannot collide on S3 bucket names, IAM
  # application names, Authentik slugs, etc.
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
  # multiple instances under one consumer don't collide. Override consults
  # var.bucket_name_override for legacy-bucket import without force-replace.
  bucket_name = var.bucket_name_override != "" ? var.bucket_name_override : "${var.base.scaleway.secrets_namespace}-${local.qualified_slug}"

  # Restic repo URI uses the bucket's regional s3 endpoint, with the scheme
  # stripped — restic expects `s3:host/bucket`, not `s3:https://host/bucket`.
  s3_endpoint_host = replace(var.base.scaleway.object_storage_endpoint, "/^https?:\\/\\//", "")
  restic_repo_uri  = var.enabled ? "s3:${local.s3_endpoint_host}/${module.bucket[0].name}" : ""

  # Full URL wins; else compose from platform icon_base_url + filename; else empty.
  effective_icon_url = (
    var.icon_url != "" ? var.icon_url :
    var.icon_filename != "" ? "${var.base.authentik.icon_base_url}/${var.icon_filename}" :
    ""
  )
}
