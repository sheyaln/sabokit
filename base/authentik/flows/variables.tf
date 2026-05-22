# FLOWS MODULE VARIABLES

variable "google_social_login_uuid" {
  description = "UUID of the Google social login source. Empty string when Google login is disabled."
  type        = string
  default     = ""
}

variable "apple_social_login_uuid" {
  description = "UUID of the Apple social login source. Empty string when Apple login is disabled."
  type        = string
  default     = ""
}

variable "member_group_id" {
  description = "ID of the standard-member group. New users created through any of the enrollment flows land here."
  type        = string
}

# SMTP CONFIGURATION VARIABLES (for email stages)

variable "smtp_host" {
  description = "SMTP host for email configuration"
  type        = string
  default     = "smtp.tem.scaleway.com"
}

variable "smtp_port" {
  description = "SMTP port for email configuration"
  type        = number
}

variable "smtp_username" {
  description = "SMTP username for email configuration"
  type        = string
  sensitive   = true
}

variable "smtp_password" {
  description = "SMTP password for email configuration"
  type        = string
  sensitive   = true
}

# ORGANIZATION CONFIGURATION VARIABLES

variable "domain" {
  description = "The base domain for the organization (used in flow titles and email bodies)."
  type        = string
  default     = "example.org"
}

variable "organisation_name" {
  description = "The organisation name shown in Authentik."
  type        = string
  default     = "Federated Commons"
}

variable "gateway_email" {
  description = "Email address for gateway notifications (derived from domain if not set)"
  type        = string
  default     = null
}

# GROUP IDS

variable "pending_activation_group_id" {
  description = "ID of the pending activation group (deprecated - not used)"
  type        = string
  default     = "" # Not used anymore - delegates create active accounts
}

# GROUP NAMES (used by the unenrollment guard policy)

variable "admin_group_name" {
  description = "Name of the admin group. Used by the unenrollment guard to block self-deletion of admins."
  type        = string
  default     = "admin"
}

variable "delegate_group_name" {
  description = "Name of the delegate group, or null when the delegate tier is not enabled. Also used by the unenrollment guard."
  type        = string
  default     = "delegate"
}

# BRANDING CONFIGURATION

variable "flow_background" {
  description = "Background image for authentication flows (S3 object name or URL)"
  type        = string
  default     = "background.jpg"
}

# USER-LIFECYCLE WEBHOOK

variable "notification_webhook_url" {
  description = "HTTP webhook called when a new user enrolls. Empty disables the webhook step."
  type        = string
  sensitive   = true
  default     = ""
}

# DERIVED LOCALS

locals {
  # Derive gateway email from domain if not explicitly set
  gateway_email = coalesce(var.gateway_email, "gateway@${var.domain}")

  # Admin-tier group names for the unenrollment guard policy. Always includes
  # admin; includes delegate when that tier exists.
  admin_tier_group_names_json = jsonencode(
    var.delegate_group_name != null
    ? [var.admin_group_name, var.delegate_group_name]
    : [var.admin_group_name]
  )
}
