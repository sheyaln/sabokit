# object_bucket

Creates a Scaleway object-storage bucket with versioning enabled and optional CORS rules. Apps that need user uploads or attachment buckets call this one per bucket.

## Usage

```hcl
module "attachments" {
  source = "git::https://github.com/sheyaln/sabokit.git//modules/infrastructure/storage/object_bucket?ref=v2.2.0"

  name = "outline-attachments-prod"

  cors_rules = [{
    allowed_headers = ["*"]
    allowed_methods = ["GET", "PUT", "POST"]
    allowed_origins = ["https://wiki.example.org"]
  }]
}
```

## Inputs

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `name` | `string` | — | Name of the bucket. |
| `region` | `string` | `"fr-par"` | Scaleway region. |
| `tags` | `map(string)` | `{}` | Tags to apply to the bucket (map of string). |
| `cors_rules` | `list(object({ allowed_headers, allowed_methods, allowed_origins, expose_headers?, max_age_seconds? }))` | `[]` | CORS configuration for the bucket. |
| `acl` | `string` | `"private"` | Bucket ACL (`private`, `public-read`, `public-read-write`, `authenticated-read`). |

## Outputs

| Name | Description |
|------|-------------|
| `bucket_id` | ID of the created Scaleway object bucket. |
| `name` | Name of the created Scaleway object bucket. |
| `region` | Region of the created Scaleway object bucket. |
| `endpoint` | Endpoint URL of the created Scaleway object bucket. |
