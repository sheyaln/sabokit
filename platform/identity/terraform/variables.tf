# ── Domain inputs ───────────────────────────────────────────────────────────
# Mirrors what base/scaleway/ outputs in its `domains` object. The consumer
# typically wires these as `base.domains.gateway_domain` / `base.domains.base_domain`.

variable "gateway_domain" {
  description = "Hostname of the Authentik gateway (e.g. \"auth.example.org\"). Matches base.domains.gateway_domain."
  type        = string
}

variable "base_domain" {
  description = "Primary apps domain (e.g. \"example.org\"). Used in branding text and notification bodies."
  type        = string
}

# ── Organization identity ───────────────────────────────────────────────────

variable "org_name" {
  description = "Organization display name shown in the Authentik UI."
  type        = string
}

variable "org_slug" {
  description = "URL-safe org slug. Used in resource names where uniqueness matters."
  type        = string
}

# ── Contact addresses ───────────────────────────────────────────────────────

variable "infra_email" {
  description = "Operations contact email shown in notification bodies."
  type        = string
}

variable "admin_email" {
  description = "Admin contact email (optional)."
  type        = string
  default     = ""
}

variable "from_name" {
  description = "Display name in SMTP From header. Defaults to org_name when empty."
  type        = string
  default     = ""
}

# ── Group taxonomy ──────────────────────────────────────────────────────────
# Group names default to generic platform terminology. Override per-org if you
# prefer "editor", "moderator", "treasurer", etc. Apps reference these by the
# string key in the output `groups` map (e.g. base.authentik.groups["admin"]),
# not by the underlying Authentik group name, so renames here are safe as long
# as you also adjust the key consumers use.

variable "admin_group_name" {
  description = "Name of the admin/superuser group. Always created."
  type        = string
  default     = "admin"
}

variable "member_group_name" {
  description = "Name of the standard-member group. Always created."
  type        = string
  default     = "member"
}

variable "delegate_group_name" {
  description = "Name of the elevated-but-not-admin group (\"delegate\", \"editor\", \"moderator\" depending on org). Set to null to skip creation."
  type        = string
  default     = "delegate"
}

variable "delegate_role_name" {
  description = "Name of the RBAC role bound to the delegate group. Only used when delegate_group_name is non-null."
  type        = string
  default     = "delegate"
}

variable "extra_groups" {
  description = "Additional Authentik groups to create at the platform level. Map of group name -> { is_superuser, description }. Use this to add org-specific roles beyond admin/member/delegate without modifying the module."
  type = map(object({
    is_superuser = optional(bool, false)
    description  = optional(string, "")
  }))
  default = {}
}

# ── Admin membership ────────────────────────────────────────────────────────
# Optional declarative control over the admin group's user list. The provider's
# `users` attribute is exclusive — setting it makes Terraform the source of
# truth, so anyone added to admin via the Authentik UI will be reconciled out
# on the next apply. Leave null to let UI-managed admin membership float.
#
# Common patterns the consumer supplies:
#   admin_user_pks = [123, 456]                              # explicit list
#   admin_user_pks = data.authentik_group.delegate.users     # mirror another group

variable "admin_user_pks" {
  description = "Optional list of user PKs (numeric IDs) that should make up the admin group. Null means UI-managed membership (default)."
  type        = list(number)
  default     = null
}

# ── Branding asset filenames ────────────────────────────────────────────────
# Paths under Authentik's custom-assets directory. The actual image files are
# deployed out-of-band by the Ansible authentik role.

variable "branding_logo" {
  description = "Filename of the logo under custom-assets."
  type        = string
  default     = "logo.png"
}

variable "branding_favicon" {
  description = "Filename of the favicon under custom-assets."
  type        = string
  default     = "favicon.png"
}

variable "branding_default_flow_background" {
  description = "Filename of the default flow background under custom-assets."
  type        = string
  default     = "background.jpg"
}

# ── Social sources ──────────────────────────────────────────────────────────
# Each source is gated by an opt-in toggle. Both default off so a fresh
# consumer doesn't pull missing secrets.

variable "enable_google_social_login" {
  description = "Whether to provision the Google OAuth social login source. Requires a Scaleway secret named \"social-google-oauth-credentials\" with client_id/client_secret keys."
  type        = bool
  default     = false
}

variable "enable_apple_social_login" {
  description = "Whether to provision the Apple OAuth social login source. Requires a Scaleway secret named \"social-apple-oauth-credentials\" with client_id/client_secret keys."
  type        = bool
  default     = false
}

# ── SMTP ────────────────────────────────────────────────────────────────────

variable "smtp_secret_name" {
  description = "Name of a Scaleway secret holding SMTP config {smtp_host, smtp_port, smtp_username, smtp_password}. Empty string disables SMTP: the email stages are still created (so the flows plan and apply) but switch to use_global_settings = true with null host/port, and any user-facing email step will no-op until the consumer creates a secret and re-applies with smtp_secret_name set."
  type        = string
  default     = ""
}

# ── Forward-auth outpost binding ────────────────────────────────────────────

variable "extra_forward_auth_provider_ids" {
  description = "Authentik provider IDs from apps/* bundles that need to be bound to the embedded outpost (Traefik forward-auth providers). Pass module.<app>.authentik_provider_id from each enabled forward-auth app, then compact() the result. See ARCHITECTURE.md \"Outpost binding mechanism\"."
  type        = list(string)
  default     = []
}

# ── Notifications ───────────────────────────────────────────────────────────

variable "notification_webhook_url" {
  description = "Optional HTTP webhook called when user-lifecycle events fire (account created, account activated). Empty disables the webhook policy. Any URL that accepts JSON POSTs works (workflow engines, custom services, chat-platform integrations, etc.)."
  type        = string
  default     = ""
  sensitive   = true
}

variable "notification_test_mode" {
  description = "When true, user-lifecycle webhooks only fire for admin-group members. Useful for verifying wiring before turning on for real users."
  type        = bool
  default     = false
}

variable "notification_support_contact_instructions" {
  description = "One-line instruction appended to user-activation notifications, e.g. \"contact your administrator at admin@example.org\"."
  type        = string
  default     = "Contact your administrator if you have questions."
}

variable "notification_welcome_message" {
  description = "Welcome line shown in user-activation notifications, e.g. \"Welcome to the platform!\"."
  type        = string
  default     = "Welcome!"
}
