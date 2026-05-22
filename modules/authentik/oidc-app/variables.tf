variable "application_name" {
  description = "Display name shown in the Authentik user portal."
  type        = string
}

variable "application_slug" {
  description = "URL-safe slug. Also used to name the per-app Authentik group and Scaleway secret."
  type        = string
}

variable "category_group" {
  description = "Category shown in the user portal grid. Free text."
  type        = string
  default     = "Tools"
}

variable "redirect_uris" {
  description = "Allowed redirect URIs for the OIDC provider. Pass full URLs; the module never assembles subdomains."
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
  description = "Optional launch URL shown in the user portal. Defaults to Authentik's first-redirect-uri behaviour."
  type        = string
  default     = null
}

variable "icon_url" {
  description = "Optional icon path (relative to Authentik media, e.g. 'outline-icon.png') or full URL."
  type        = string
  default     = null
}

variable "description" {
  description = "Optional one-line app description shown in the user portal."
  type        = string
  default     = null
}

variable "authorized_group_ids" {
  description = "Authentik group IDs allowed to access this application. The module creates one policy binding per group."
  type        = list(string)

  validation {
    condition     = length(var.authorized_group_ids) > 0
    error_message = "At least one authorized group ID must be provided. To restrict the application to administrators only, pass [base.authentik.groups[\"admin\"]]."
  }
}

variable "oidc_scopes" {
  description = "OIDC scopes the provider will expose. Defaults cover the common set; pass a different list to opt out of any."
  type        = list(string)
  default     = ["openid", "profile", "email", "groups"]

  validation {
    condition = alltrue([
      for scope in var.oidc_scopes : contains([
        "openid", "profile", "email", "entitlements", "offline_access", "groups",
        "goauthentik.io/api", "user", "read:user", "user:email", "read:org"
      ], scope)
    ])
    error_message = "OIDC scope must be one of: openid, profile, email, entitlements, offline_access, groups, goauthentik.io/api, user, read:user, user:email, read:org. Custom scopes are injected via additional_property_mapping_ids."
  }
}

variable "additional_property_mapping_ids" {
  description = "IDs of property mappings the consumer wants attached to the provider in addition to the built-in scope mappings. Use this to inject app-specific custom scopes."
  type        = list(string)
  default     = []
}

variable "access_token_validity" {
  description = "Access token validity (Authentik duration syntax, e.g. 'minutes=10', 'hours=1')."
  type        = string
  default     = "minutes=10"
}

variable "refresh_token_validity" {
  description = "Refresh token validity (Authentik duration syntax)."
  type        = string
  default     = "days=30"
}

variable "sub_mode" {
  description = "OIDC sub claim mode. 'user_email', 'user_id', 'user_uuid', or 'hashed_user_id'."
  type        = string
  default     = "user_email"
}

variable "authentication_flow_uuid" {
  description = "Authentication flow UUID. From base.authentik.flows.authentication_flow."
  type        = string
}

variable "authorization_flow_uuid" {
  description = "Authorization flow UUID. From base.authentik.flows.authorization_flow."
  type        = string
}

variable "invalidation_flow_uuid" {
  description = "Invalidation flow UUID. From base.authentik.flows.invalidation_flow."
  type        = string
}

variable "generate_rsa_signing_key" {
  description = "If true, generate a dedicated RSA signing key for this app. Otherwise use the Authentik default self-signed certificate."
  type        = bool
  default     = false
}

variable "signing_key_subject" {
  description = "Subject for the RSA signing certificate when generate_rsa_signing_key is true. Object with common_name and organization."
  type = object({
    common_name  = string
    organization = string
  })
  default = {
    common_name  = "authentik.example.org"
    organization = "Federated Commons"
  }
}
