# Restic encrypts the repository with this password. There is no recovery
# path: losing it means losing every backup in the bucket. ignore_changes
# locks the value for the lifetime of the deployment — to rotate, operators
# must taint this resource AND run `restic key add` against the live repo
# before re-applying, otherwise existing snapshots become unreadable.
resource "random_password" "restic" {
  count   = var.enabled ? 1 : 0
  length  = 48
  special = false

  lifecycle {
    ignore_changes = all
  }
}

resource "scaleway_secret" "app" {
  count = var.enabled ? 1 : 0

  name        = "${local.qualified_slug}-app-secrets"
  description = "Backrest restic repo credentials + encryption password (${local.qualified_slug})."
  tags        = ["automated", local.slug, var.instance_name]
  type        = "key_value"
}

resource "scaleway_secret_version" "app" {
  count = var.enabled ? 1 : 0

  secret_id = scaleway_secret.app[0].id
  data = jsonencode({
    RESTIC_PASSWORD       = random_password.restic[0].result
    AWS_ACCESS_KEY_ID     = scaleway_iam_api_key.storage[0].access_key
    AWS_SECRET_ACCESS_KEY = scaleway_iam_api_key.storage[0].secret_key
    S3_ENDPOINT           = var.base.scaleway.object_storage_endpoint
    S3_BUCKET             = module.bucket[0].name
    S3_REGION             = var.base.scaleway.region
    RESTIC_REPO_URI       = local.restic_repo_uri
  })

  lifecycle {
    # RESTIC_PASSWORD has ignore_changes upstream and the bucket/IAM key are
    # stable across apply unless they're explicitly tainted, so the rendered
    # JSON is identical run-to-run. Skipping replace prevents transient diffs
    # if the IAM key gets silently rotated underneath us.
    ignore_changes = [data]
  }
}
