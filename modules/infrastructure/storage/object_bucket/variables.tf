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
