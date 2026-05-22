resource "scaleway_object_bucket" "this" {
  name   = var.name
  region = var.region
  acl    = var.acl

  versioning {
    enabled = true
  }

  dynamic "cors_rule" {
    for_each = var.cors_rules
    content {
      allowed_headers = cors_rule.value.allowed_headers
      allowed_methods = cors_rule.value.allowed_methods
      allowed_origins = cors_rule.value.allowed_origins
      expose_headers  = cors_rule.value.expose_headers
      max_age_seconds = cors_rule.value.max_age_seconds
    }
  }

  tags = var.tags
}

output "bucket_id" {
  description = "ID of the created Scaleway object bucket"
  value       = scaleway_object_bucket.this.id
}

output "name" {
  description = "Name of the created Scaleway object bucket"
  value       = scaleway_object_bucket.this.name
}

output "region" {
  description = "Region of the created Scaleway object bucket"
  value       = scaleway_object_bucket.this.region
}

output "endpoint" {
  description = "Endpoint URL of the created Scaleway object bucket"
  value       = scaleway_object_bucket.this.endpoint
}
