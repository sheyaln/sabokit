module "files_bucket" {
  source = "../../../../modules/infrastructure/storage/object_bucket"
  count  = var.enabled ? 1 : 0

  name   = local.bucket_name
  region = var.base.scaleway.region
  acl    = "private"
  tags = {
    app  = local.slug
    role = "files"
  }

  cors_rules = [{
    allowed_headers = ["*"]
    allowed_methods = ["GET", "PUT", "POST", "DELETE", "HEAD"]
    allowed_origins = [local.app_url]
    expose_headers  = ["ETag", "Content-Length", "Content-Type"]
    max_age_seconds = 3600
  }]
}

resource "scaleway_iam_application" "storage" {
  count = var.enabled ? 1 : 0

  name        = "${var.base.scaleway.secrets_namespace}-${local.slug}-s3-access"
  description = "S3 access for Notifuse files bucket (${var.base.scaleway.secrets_namespace})"
  tags        = ["automated", local.slug, "storage"]
}

resource "scaleway_iam_policy" "storage" {
  count = var.enabled ? 1 : 0

  name           = "${var.base.scaleway.secrets_namespace}-${local.slug}-s3-policy"
  description    = "Object Storage access for Notifuse files bucket (${var.base.scaleway.secrets_namespace})"
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
  description    = "API key for Notifuse S3 files access"
}
