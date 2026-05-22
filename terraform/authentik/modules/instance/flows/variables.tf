# FLOWS MODULE VARIABLES

variable "google_social_login_uuid" {
  description = "UUID of the Google social login source"
  type        = string
}

variable "apple_social_login_uuid" {
  description = "UUID of the Apple social login source"
  type        = string
}

variable "union_member_group_id" {
  description = "ID of the union member group"
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
  description = "The domain for the organization"
  type        = string
  default     = "example.org"
}

variable "organisation_name" {
  description = "The organisation name for Authentik"
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

# BRANDING CONFIGURATION

variable "flow_background" {
  description = "Background image for authentication flows (S3 object name or URL)"
  type        = string
  default     = "background.jpg"
}

# N8N WEBHOOK CONFIGURATION

variable "n8n_webhook_user_notifications" {
  description = "N8N webhook URL for user lifecycle notifications (handles Slack threading and emails)"
  type        = string
  sensitive   = true
  default     = ""
}

# DERIVED LOCALS

locals {
  # Derive gateway email from domain if not explicitly set
  gateway_email = coalesce(var.gateway_email, "gateway@${var.domain}")
}

