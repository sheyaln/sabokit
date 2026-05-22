module "attachments_bucket" {
  source = "../../../../modules/infrastructure/storage/object_bucket"
  count  = var.enabled ? 1 : 0

  name   = local.bucket_name
  region = var.base.scaleway.region
  acl    = var.storage_bucket_acl
  tags = {
    app  = local.slug
    role = "attachments"
  }

  cors_rules = [{
    allowed_headers = ["*"]
    allowed_methods = ["GET", "PUT", "POST", "DELETE", "HEAD"]
    allowed_origins = [local.app_url]
    expose_headers  = ["ETag", "Content-Length", "Content-Type"]
    max_age_seconds = 3600
  }]
}

# IAM principal + API key for Outline to access its bucket.
# Inlined here because the pattern is per-app; refactor to a helper module
# once 3+ apps need it.

resource "scaleway_iam_application" "storage" {
  count = var.enabled ? 1 : 0

  name        = "${local.slug}-s3-access"
  description = "S3 access for Outline attachments bucket"
  tags        = ["automated", local.slug, "storage"]
}

resource "scaleway_iam_policy" "storage" {
  count = var.enabled ? 1 : 0

  name           = "${local.slug}-s3-policy"
  description    = "Object Storage access for Outline attachments bucket"
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
  description    = "API key for Outline S3 attachments"
}
