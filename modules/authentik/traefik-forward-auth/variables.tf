variable "application_name" {
  description = "Display name for the application"
  type        = string
}

variable "application_slug" {
  description = "URL-friendly slug for the application"
  type        = string
}

variable "external_host" {
  description = "The external URL of the application being protected (e.g., https://app.example.org)"
  type        = string
}

variable "category_group" {
  description = "Category group for the application in Authentik UI"
  type        = string
  default     = "Member Tools"
}

variable "launch_url" {
  description = "Launch URL for the application (defaults to external_host if not specified)"
  type        = string
  default     = null
}

variable "icon_url" {
  description = "Icon URL for the application"
  type        = string
  default     = null
}

variable "description" {
  description = "Description for the application"
  type        = string
  default     = null
}

variable "access_level" {
  description = "Access level: admin, delegate, treasurer, or member"
  type        = string
  validation {
    condition     = contains(["admin", "delegate", "treasurer", "member"], var.access_level)
    error_message = "Access level must be one of: admin, delegate, treasurer, member."
  }
}

variable "group_ids" {
  description = "Map of group IDs for access control"
  type = object({
    admin           = string
    union_delegate  = string
    union_treasurer = string
    union_member    = string
  })
}

# Flow Configuration
variable "authentication_flow_uuid" {
  description = "UUID of the authentication flow"
  type        = string
}

variable "authorization_flow_uuid" {
  description = "UUID of the authorization flow"
  type        = string
}

variable "invalidation_flow_uuid" {
  description = "UUID of the invalidation flow"
  type        = string
}

# Token and Cookie Settings
variable "access_token_validity" {
  description = "Access token validity duration (e.g., 'minutes=10', 'hours=1')"
  type        = string
  default     = "hours=24"
}

variable "cookie_domain" {
  description = "Cookie domain for forward auth sessions (e.g., 'example.org' for *.example.org)"
  type        = string
  default     = null
}

# Path Skipping (for webhooks, health checks, etc.)
variable "skip_path_regex" {
  description = "Regex pattern for paths to skip authentication (e.g., '^/health$|^/api/webhooks')"
  type        = string
  default     = ""
}

# Basic Auth (rarely needed)
variable "basic_auth_enabled" {
  description = "Enable basic auth header passthrough (for API access)"
  type        = bool
  default     = false
}
