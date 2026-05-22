# ── Domains ─────────────────────────────────────────────────────────────────
# Each env passes its own domain set. In prod, `domain` is the apps' domain
# (e.g. dciww.org) and `mgmt_domain` is the operations domain (dciww.cc). In
# staging, both collapse to a single staging domain since everything runs on
# one VPS — pass the same value for both.

variable "domain" {
  description = "Primary apps domain (e.g. dciww.org for prod, dciww.com for staging)"
  type        = string
}

variable "mgmt_domain" {
  description = "Domain for management apps (Grafana, Zabbix, n8n, Wazuh, backrest). Pass = var.domain when there's no separate management host (staging)."
  type        = string
}

variable "gateway_domain" {
  description = "Hostname of the Authentik gateway/admin (convention: gateway.<domain>)"
  type        = string
}

# ── Organization identity ───────────────────────────────────────────────────

variable "org_name" {
  description = "Org display name shown in Authentik UI (used as 'NAME Gateway' in brand titles)"
  type        = string
}

variable "org_slug" {
  description = "URL-safe org slug"
  type        = string
}

# ── Emails ──────────────────────────────────────────────────────────────────

variable "infra_email" {
  description = "Operations contact email (used in notification policy bodies)"
  type        = string
}

variable "admin_email" {
  description = "Admin contact email"
  type        = string
  default     = ""
}

variable "from_name" {
  description = "Display name shown in SMTP From: header (falls back to org_name)"
  type        = string
  default     = ""
}

# ── Branding assets ─────────────────────────────────────────────────────────
# Paths are relative to the Authentik custom-assets dir. Logo/favicon files
# must be uploaded out-of-band (deployed by Ansible's authentik role).

variable "branding_logo" {
  description = "Filename of the logo under custom-assets"
  type        = string
  default     = "logo.png"
}

variable "branding_favicon" {
  description = "Filename of the favicon under custom-assets"
  type        = string
  default     = "favicon.png"
}

variable "branding_default_flow_background" {
  description = "Filename of the default flow background image under custom-assets"
  type        = string
  default     = "background.jpg"
}

# ── Notifications ───────────────────────────────────────────────────────────

variable "n8n_webhook_user_notifications" {
  description = "n8n webhook URL for user lifecycle events. Leave empty to use the value from the 'n8n-webhook-user-notifications-url' Scaleway secret. Set explicitly to override (e.g. for staging where the secret may not exist yet)."
  type        = string
  default     = ""
  sensitive   = true
}

# ── Cross-env redirect escape hatch ─────────────────────────────────────────
# Some apps have OIDC redirect URIs from a *different* environment registered
# on a *single* Authentik instance (e.g. prod's Jitsi accepted both
# meet.dciww.org and meet.dciww.com during the transition). This map is a
# generic way to append extras without forking app definitions in the module.
# Key: app slug. Value: list of full redirect URLs. Empty by default.
variable "extra_redirect_uris" {
  description = "Map of app slug → list of additional OIDC redirect URIs to append. Used for cross-env transitions. Empty = no extras."
  type        = map(list(string))
  default     = {}
}
