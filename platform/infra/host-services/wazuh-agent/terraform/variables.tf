# ── Contract inputs ─────────────────────────────────────────────────────────

variable "enabled" {
  description = "Master toggle. When false the bundle provisions zero resources."
  type        = bool
  default     = false
}

variable "base" {
  description = "Outputs from module \"base\". Agent only consumes deployment_host_key."
  type        = any
}

variable "deployment_host_key" {
  description = "Key in base.compute.hosts identifying the VM this Wazuh agent runs on. Multi-instance: one block per host you want monitored."
  type        = string
}

# ── Agent-specific inputs ───────────────────────────────────────────────────

variable "image" {
  description = "Wazuh agent Docker image (without tag)."
  type        = string
  default     = "wazuh/wazuh-agent"
}

variable "release_version" {
  description = "Wazuh release version. MUST match the version of the Wazuh manager this agent reports to."
  type        = string
  default     = "4.9.0"
}

variable "agent_name" {
  description = "The agent's name as registered with the manager. Defaults to the deployment_host_key. Use a stable string — re-enrollment under a different name creates a new agent record."
  type        = string
  default     = ""
}

variable "manager_address" {
  description = "Network address of the Wazuh manager. Use the manager's private-network IP (preferred) or a DNS name resolvable from this host. The manager bundle's required_inbound_rules opens TCP 1514+1515 + UDP 514 on the host SG."
  type        = string
}

variable "registration_secret_id" {
  description = "Scaleway secret ID of the manager bundle's app-secrets bag (its `app_secret_id` output). The agent fetches WAZUH_AUTHD_PASSWORD from it and presents it on enrollment — the manager requires it (use_password=yes). Required: the manager rejects passwordless enrollment."
  type        = string
}

variable "diun_watch_enabled" {
  description = "Whether Diun watches this app's containers for upstream image updates. When true (default) the bundle emits a `diun.enable=true` label on each compose service, opting it into the platform Diun bundle's registry polling. Flip false to silence notifications for this app."
  type        = bool
  default     = true
}

variable "autoheal_enabled" {
  description = "Whether the Autoheal platform bundle restarts the agent when its healthcheck fails. Default true."
  type        = bool
  default     = true
}

# ── File Integrity Monitoring ───────────────────────────────────────────────

variable "fim_enabled" {
  description = "Master toggle for File Integrity Monitoring. Default TRUE — ships syscheck + auditd integration covering /etc, /root/.ssh, /boot, /usr/bin, /usr/sbin, /bin, /sbin and the standard config/cron/systemd paths. Disable only if you ship FIM another way."
  type        = bool
  default     = true
}

variable "fim_extra_paths" {
  description = "Additional absolute paths to monitor on top of the standard set. Added to both the host auditd rules (-w … -p wa) and the agent's syscheck stanza."
  type        = list(string)
  default     = []
}

variable "fim_extra_exclusions" {
  description = "Absolute paths or globs to exclude from syscheck reporting (added as <ignore> entries). Use to silence known-noisy files inside otherwise monitored directories."
  type        = list(string)
  default     = []
}

variable "extra_env_vars" {
  description = "Map of KEY → value rendered into the container .env after first-class vars. Use for env-driven feature flags / third-party integrations / debug toggles not exposed first-class on the bundle."
  type        = map(string)
  default     = {}
}
