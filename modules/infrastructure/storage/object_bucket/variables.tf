variable "name" {
  description = "Name of the bucket"
  type        = string
}

variable "region" {
  description = "Scaleway region"
  type        = string
  default     = "fr-par"
}

variable "tags" {
  description = "Tags to apply to the bucket (map of string)"
  type        = map(string)
  default     = {}
}

variable "cors_rules" {
  description = "CORS configuration for the bucket"
  type = list(object({
    allowed_headers = list(string)
    allowed_methods = list(string)
    allowed_origins = list(string)
    expose_headers  = optional(list(string), [])
    max_age_seconds = optional(number, 3600)
  }))
  default = []
}

variable "acl" {
  description = "Bucket ACL (private, public-read, public-read-write, authenticated-read)"
  type        = string
  default     = "private"
}

variable "storage_class" {
  description = "Scaleway storage class objects auto-transition to after `storage_class_transition_days`. `STANDARD` (Multi-AZ, the default) skips creating any lifecycle rule. `GLACIER` (cold) and `ONEZONE_IA` (single-AZ, infrequent access) are the cheaper alternatives. Scaleway has no bucket-level storage class — this is implemented as a lifecycle_rule transition. Apps that natively support setting storage class on upload (restic for backrest, S3 SDKs for Nextcloud) can additionally skip the warm window by configuring uploads to write directly into the target class."
  type        = string
  default     = "STANDARD"
  validation {
    condition     = contains(["STANDARD", "GLACIER", "ONEZONE_IA"], var.storage_class)
    error_message = "storage_class must be one of: STANDARD, GLACIER, ONEZONE_IA."
  }
}

variable "storage_class_transition_days" {
  description = "Number of days after object creation before the lifecycle rule transitions objects to `storage_class`. Only consulted when `storage_class != STANDARD`. Minimum 1. For backrest where every object is cold by definition, 1 day is appropriate — one day at STANDARD rate, then cold thereafter."
  type        = number
  default     = 1
  validation {
    condition     = var.storage_class_transition_days >= 1
    error_message = "storage_class_transition_days must be >= 1."
  }
}
