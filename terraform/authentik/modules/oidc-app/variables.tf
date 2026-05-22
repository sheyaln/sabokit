variable "application_name" {
  description = "Display name for the application"
  type        = string
}

variable "gateway_domain" {
  description = "Gateway domain for signing certificates (e.g., gateway.example.org)"
  type        = string
  default     = "gateway.example.org"
}

variable "org_name" {
  description = "Organization name for signing certificates"
  type        = string
  default     = "Federated Commons"
}

variable "application_slug" {
  description = "URL-friendly slug for the application"
  type        = string
}

variable "category_group" {
  description = "Category group for the application"
  type        = string
  default     = "Member Tools"
}

variable "redirect_uris" {
  description = "Valid redirect URIs for the OIDC provider"
  type = list(object({
    matching_mode = optional(string, "strict")
    url           = string
  }))

  validation {
    condition     = length(var.redirect_uris) > 0
    error_message = "At least one redirect_uri must be provided."
  }
}

variable "launch_url" {
  description = "Launch URL for the application"
  type        = string
  default     = null
}

variable "icon_url" {
  description = "Icon URL for the application (relative to Authentik media, e.g., 'nextcloud.png')"
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

# OIDC Provider Configuration
variable "oidc_scopes" {
  description = "List of OIDC scopes to include in the provider"
  type        = list(string)
  default     = ["openid", "profile", "email", "groups"]

  validation {
    condition = alltrue([
      for scope in var.oidc_scopes : contains([
        "openid", "profile", "email", "entitlements", "offline_access", "groups",
        "goauthentik.io/api", "user", "read:user", "user:email", "read:org",
        "vikunja_scope"
      ], scope)
    ])
    error_message = "OIDC scopes must be valid authentik scopes. Valid scopes are: openid, profile, email, entitlements, offline_access, groups, goauthentik.io/api, user, read:user, user:email, read:org, vikunja_scope."
  }
}

variable "vikunja_team_name" {
  description = "Team name for Vikunja OIDC team assignment"
  type        = string
  default     = null
}

variable "access_token_validity" {
  description = "Access token validity duration (e.g., 'minutes=10', 'hours=1')"
  type        = string
  default     = "minutes=10"
}

variable "refresh_token_validity" {
  description = "Refresh token validity duration (e.g., 'days=30', 'hours=24')"
  type        = string
  default     = "days=30"
}

variable "sub_mode" {
  description = "Subject mode for the application"
  type        = string
  default     = "user_email"
}

# Authentication Flow Configuration
variable "authentication_flow_uuid" {
  description = "Custom authentication flow slug"
  type        = string
}

variable "authorization_flow_uuid" {
  description = "Custom authorization flow UUID"
  type        = string
}

variable "invalidation_flow_uuid" {
  description = "Custom invalidation flow slug"
  type        = string
}

variable "generate_rsa_signing_key" {
  description = "Whether to generate an RSA signing key for the application"
  type        = bool
  default     = false
}
