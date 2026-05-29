# Each Backrest instance gets its own restic repository on its own S3 bucket.
# A shared bucket with subdirs would work for restic but couples instances'
# IAM blast radius — one leaked key would expose every host's snapshots.
# Per-instance bucket + per-instance IAM application keeps each host's
# backups isolated.

module "bucket" {
  source = "../../../_shared/infrastructure/storage/object_bucket"
  count  = var.enabled ? 1 : 0

  name   = local.bucket_name
  region = var.base.scaleway.region
  acl    = "private"

  storage_class                 = var.storage_class
  storage_class_transition_days = var.storage_class_transition_days

  tags = {
    app      = local.slug
    instance = var.instance_name
    role     = "restic-repo"
  }
}

# IAM application + policy + API key — same shape as outline/storage.tf.
# Scoped to a single bucket so a leaked key can only touch this instance's
# repo, not the consumer's other object storage.

resource "scaleway_iam_application" "storage" {
  count = var.enabled ? 1 : 0

  # IAM applications are organization-scoped (not project-scoped), so two
  # consumers in the same org — or one consumer with prod + staging — would
  # otherwise collide on the bare slug. Namespace by secrets_namespace + the
  # instance-qualified slug.
  name        = "${var.base.scaleway.secrets_namespace}-${local.qualified_slug}-s3-access"
  description = "S3 access for Backrest restic repo (${local.qualified_slug})"
  tags        = ["automated", local.slug, var.instance_name, "storage"]
}

resource "scaleway_iam_policy" "storage" {
  count = var.enabled ? 1 : 0

  name           = "${var.base.scaleway.secrets_namespace}-${local.qualified_slug}-s3-policy"
  description    = "Object Storage access for Backrest restic repo (${local.qualified_slug})"
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
  description    = "API key for Backrest restic repo (${local.qualified_slug})"
}
