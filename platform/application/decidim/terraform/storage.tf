module "uploads_bucket" {
  source = "../../../_shared/infrastructure/storage/object_bucket"
  count  = var.enabled ? 1 : 0

  name   = local.bucket_name
  region = var.base.scaleway.region
  acl    = var.storage_public ? "public-read" : "private"

  storage_class                 = var.storage_class
  storage_class_transition_days = var.storage_class_transition_days

  tags = {
    app  = local.slug
    role = "uploads"
  }

  cors_rules = [{
    allowed_headers = ["*"]
    allowed_methods = ["GET", "PUT", "POST", "DELETE", "HEAD"]
    allowed_origins = [local.app_url]
    expose_headers  = ["ETag", "Content-Length", "Content-Type"]
    max_age_seconds = 3600
  }]
}

# IAM principal + API key for Decidim's Active Storage S3 adapter.
# IAM applications are organization-scoped — prefix with the env namespace so
# two consumers (or staging + prod) sharing one Scaleway org don't collide.

resource "scaleway_iam_application" "storage" {
  count = var.enabled ? 1 : 0

  name        = "${var.base.scaleway.secrets_namespace}-${local.slug}-s3-access"
  description = "S3 access for Decidim uploads bucket (${var.base.scaleway.secrets_namespace})"
  tags        = ["automated", local.slug, "storage"]
}

resource "scaleway_iam_policy" "storage" {
  count = var.enabled ? 1 : 0

  name           = "${var.base.scaleway.secrets_namespace}-${local.slug}-s3-policy"
  description    = "Object Storage access for Decidim uploads bucket (${var.base.scaleway.secrets_namespace})"
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
  description    = "API key for Decidim S3 uploads"
}
