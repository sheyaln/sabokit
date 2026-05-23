module "data_bucket" {
  source = "../../../../modules/infrastructure/storage/object_bucket"
  count  = var.enabled ? 1 : 0

  name   = local.bucket_name
  region = var.base.scaleway.region
  acl    = "private"
  tags = {
    app  = local.slug
    role = "primary-storage"
  }
}

# IAM principal + API key for Nextcloud to access its primary-storage bucket.
# Inlined per app (same pattern as outline/notifuse); refactor to a helper
# module once 3+ apps need it.

resource "scaleway_iam_application" "storage" {
  count = var.enabled ? 1 : 0

  # IAM applications and policies are organization-scoped, not project-scoped:
  # two consumers (or one consumer's staging + prod) sharing a Scaleway org
  # would otherwise collide on the bare "nextcloud-s3-access" name. Prefix with
  # the org+env namespace so each environment owns its own principal.
  name        = "${var.base.scaleway.secrets_namespace}-${local.slug}-s3-access"
  description = "S3 access for Nextcloud primary-storage bucket (${var.base.scaleway.secrets_namespace})"
  tags        = ["automated", local.slug, "storage"]
}

resource "scaleway_iam_policy" "storage" {
  count = var.enabled ? 1 : 0

  name           = "${var.base.scaleway.secrets_namespace}-${local.slug}-s3-policy"
  description    = "Object Storage access for Nextcloud primary-storage bucket (${var.base.scaleway.secrets_namespace})"
  application_id = scaleway_iam_application.storage[0].id

  rule {
    project_ids = [var.base.scaleway.project_id]
    permission_set_names = [
      "ObjectStorageObjectsRead",
      "ObjectStorageObjectsWrite",
      "ObjectStorageObjectsDelete",
      "ObjectStorageBucketsRead",
    ]
  }
}

resource "scaleway_iam_api_key" "storage" {
  count = var.enabled ? 1 : 0

  application_id = scaleway_iam_application.storage[0].id
  description    = "API key for Nextcloud S3 primary storage"
}
