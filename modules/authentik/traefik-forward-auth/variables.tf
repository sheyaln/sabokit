variable "application_name" {
  description = "Display name shown in the Authentik user portal."
  type        = string
}

variable "application_slug" {
  description = "URL-safe slug. Also used to name the per-app Authentik group."
  type        = string
}

variable "external_host" {
  description = "External URL of the application being protected (e.g., 'https://app.example.org'). Pass a full URL; the module never assembles subdomains."
  type        = string
}

variable "category_group" {
  description = "Category shown in the user portal grid. Free text."
  type        = string
  default     = "Tools"
}

variable "launch_url" {
  description = "Launch URL for the application. Defaults to external_host."
  type        = string
  default     = null
}

variable "icon_url" {
  description = "Optional icon — full URL or Authentik-media-relative path. Empty falls back to `default-logo.png`."
  type        = string
  default     = ""
}

variable "description" {
  description = "Optional one-line app description."
  type        = string
  default     = null
}

variable "authorized_groups" {
  description = "Map of role-name → Authentik group ID for groups allowed to access this application. Keys MUST be static strings (e.g. \"admin\", \"member\", \"delegate\") so for_each can plan even when group IDs are not yet known. The module creates one policy binding per entry."
  type        = map(string)

  validation {
    condition     = length(var.authorized_groups) > 0
    error_message = "At least one authorized group must be provided. To restrict the application to administrators only, pass { admin = base.authentik.groups[\"admin\"] }."
  }
}

variable "authentication_flow_uuid" {
  description = "Authentication flow UUID."
  type        = string
}

variable "authorization_flow_uuid" {
  description = "Authorization flow UUID."
  type        = string
}

variable "invalidation_flow_uuid" {
  description = "Invalidation flow UUID."
  type        = string
}

variable "access_token_validity" {
  description = "Access token validity (Authentik duration syntax)."
  type        = string
  default     = "hours=24"
}

variable "cookie_domain" {
  description = "Cookie domain for forward auth sessions (e.g., 'example.org' to share session across *.example.org)."
  type        = string
  default     = null
}

variable "skip_path_regex" {
  description = "Regex pattern for paths that bypass authentication (e.g., '^/health$|^/api/webhooks')."
  type        = string
  default     = ""
}

variable "basic_auth_enabled" {
  description = "If true, pass through HTTP Basic Auth headers (for API access alongside browser-based forward auth)."
  type        = bool
  default     = false
}
