# ── Contract inputs (every app bundle has these) ────────────────────────────

variable "enabled" {
  description = "Master toggle. When false the bundle provisions zero resources."
  type        = bool
  default     = false
}

variable "base" {
  description = "Outputs from module \"base\". Apps consume { scaleway, authentik, compute, domains } from this. Shape documented in /ARCHITECTURE.md (\"What base/ outputs\")."
  type        = any
}

variable "hostname" {
  description = "Full hostname Notifuse is served at (e.g. \"email.example.org\"). Never assembled from a subdomain prefix inside the module."
  type        = string
  default     = ""
}

variable "category_group" {
  description = "Authentik portal category."
  type        = string
  default     = "Productivity"
}

variable "icon_url" {
  description = "Optional icon path in Authentik media (e.g. \"notifuse-icon.png\")."
  type        = string
  default     = null
}

variable "access_level" {
  description = "Key in base.authentik.groups granting baseline access."
  type        = string
  default     = "admin"
}

variable "extra_authorized_groups" {
  description = "Additional Authentik groups allowed to access Notifuse beyond access_level. Map of role-name → group ID; keys MUST be static strings so for_each can plan even when group IDs are not yet known."
  type        = map(string)
  default     = {}
}

variable "monitoring_enabled" {
  description = "If true and a monitoring app is enabled, Notifuse's log paths wire in. No effect when monitoring apps are disabled."
  type        = bool
  default     = true
}

variable "deployment_host_key" {
  description = "Key in base.compute.hosts identifying the VM this app deploys to. The Ansible playbook targets this host's ansible_group."
  type        = string
  default     = "apps"
}

# ── Notifuse-specific inputs ────────────────────────────────────────────────

variable "image" {
  description = "Notifuse Docker image repository (without tag). Stock `notifuse/notifuse` does NOT support OIDC — the bundle wires OIDC envs unconditionally, so a stock image will silently ignore them and require local-account login. For OIDC, point at a build that includes the github.com/sheyaln/notifuse `feat/oidc-v1` patch set (either a fork-published image like `ghcr.io/sheyaln/notifuse`, or use `build_from_source = true` to build on the host from the cloned repo)."
  type        = string
  default     = "notifuse/notifuse"
}

variable "image_tag" {
  description = "Notifuse Docker image tag. Pin in production."
  type        = string
  default     = "latest"
}

variable "build_from_source" {
  description = "Build the Notifuse image on the deployment host from a cloned git repo instead of pulling. Default `true` so OIDC works out of the box (stock `notifuse/notifuse:latest` lacks OIDC; the patches live on the sheyaln fork). When true, `image_source_repo` + `image_source_ref` define the checkout; the resulting image is tagged `notifuse-local:latest` on the host and `image`/`image_tag` are ignored. Flip to `false` to pull a published image instead (only useful once a fork-built image is hosted)."
  type        = bool
  default     = true
}

variable "image_source_repo" {
  description = "Git URL the host clones when `build_from_source = true`. Defaults to the OIDC-enabled fork."
  type        = string
  default     = "https://github.com/sheyaln/notifuse.git"
}

variable "image_source_ref" {
  description = "Git ref (branch, tag, or SHA) checked out when `build_from_source = true`. Pin to a SHA for reproducibility."
  type        = string
  default     = "feat/oidc-v1"
}

variable "root_admin_email" {
  description = "Email address of the initial root administrator. Used both as the ROOT_EMAIL fallback identity and as ROOT_ADMIN_EMAIL for the bootstrap login. The matching password is auto-generated and stored in the app-secrets bag."
  type        = string
}

variable "smtp_from_email" {
  description = "From: address for Notifuse-sent transactional email (e.g. \"notify@example.org\"). Required — Notifuse uses SMTP heavily. SMTP host/port/username/password come from the platform-wide smtp-config secret looked up by the Ansible role."
  type        = string
  default     = ""
}

variable "oidc_auto_provision" {
  description = "Whether Notifuse auto-provisions a user record on first OIDC login. Set false to require pre-created users."
  type        = bool
  default     = true
}

variable "oidc_allow_magic_code" {
  description = "Whether Notifuse offers its magic-code (email link) fallback alongside OIDC. Recommended to leave on so admins can recover if OIDC is misconfigured."
  type        = bool
  default     = true
}
