# ── Contract inputs ─────────────────────────────────────────────────────────

variable "enabled" {
  description = "Master toggle. When false the bundle provisions zero resources."
  type        = bool
  default     = false
}

variable "base" {
  description = "Outputs from module \"base\"."
  type        = any
}

variable "hostname" {
  description = "Full hostname the Wazuh dashboard is served at (e.g. \"wazuh.example.org\")."
  type        = string
  default     = ""
}

variable "category_group" {
  description = "Authentik portal category."
  type        = string
  default     = "Security"
}

variable "icon_url" {
  description = "Optional icon path in Authentik media."
  type        = string
  default     = null
}

variable "access_level" {
  description = "Key in base.authentik.groups granting baseline access. Defaults to \"admin\" — Wazuh exposes SIEM data + active response controls, ops-only by default."
  type        = string
  default     = "admin"
}

variable "extra_authorized_groups" {
  description = "Additional Authentik groups allowed beyond access_level."
  type        = map(string)
  default     = {}
}

variable "monitoring_enabled" {
  description = "If true and a monitoring app is enabled, Wazuh's log paths wire in."
  type        = bool
  default     = true
}

variable "deployment_host_key" {
  description = "Key in base.compute.hosts identifying the VM this Wazuh manager runs on. Typically your monitoring/security host."
  type        = string
  default     = "management"
}

# ── Wazuh-specific inputs ───────────────────────────────────────────────────

variable "release_version" {
  description = "Wazuh release version (used for ALL three images: manager, indexer, dashboard, and the cert generator). The three images MUST run lockstep."
  type        = string
  default     = "4.9.0"
}

variable "indexer_heap_size" {
  description = "JVM heap size for the indexer (OpenSearch). Rule of thumb: 50%% of host RAM, max 31g. Bump for larger event volumes."
  type        = string
  default     = "1g"
}

variable "manager_agent_port" {
  description = "TCP port the Wazuh manager listens on for agent connections."
  type        = number
  default     = 1514
}

variable "manager_enrollment_port" {
  description = "TCP port the Wazuh manager listens on for agent enrollment."
  type        = number
  default     = 1515
}

variable "manager_syslog_port" {
  description = "UDP port the Wazuh manager listens on for syslog ingestion."
  type        = number
  default     = 514
}

variable "memory_limit" {
  description = "Container memory ceiling — applies to the manager (the indexer's heap is set separately via indexer_heap_size)."
  type        = string
  default     = "2G"
}

variable "memory_reservation" {
  description = "Container memory reservation for the manager."
  type        = string
  default     = "512M"
}

variable "cpu_limit" {
  description = "Container CPU ceiling for the manager."
  type        = string
  default     = "2.0"
}

variable "cpu_reservation" {
  description = "Container CPU reservation for the manager."
  type        = string
  default     = "0.5"
}

variable "auto_update_enabled" {
  description = "Whether the Watchtower platform bundle auto-pulls newer Wazuh image versions. Default FALSE — the three images MUST move in lockstep + new versions occasionally require index schema migrations. Bump `version` explicitly so Ansible coordinates the upgrade."
  type        = bool
  default     = false
}

variable "autoheal_enabled" {
  description = "Whether the Autoheal platform bundle restarts Wazuh containers on healthcheck failure. Default true."
  type        = bool
  default     = true
}

variable "backup_enabled" {
  description = "Whether the Backrest platform bundle backs up Wazuh's indexer data + manager state. Default true."
  type        = bool
  default     = true
}

variable "backup_extra_paths" {
  description = "Additional restic paths. The indexer + manager state lives in named volumes; defaults below cover them."
  type        = list(string)
  default = [
    "/backup-sources/docker-volumes/wazuh_wazuh-indexer-data/_data",
    "/backup-sources/docker-volumes/wazuh_wazuh_etc/_data",
    "/backup-sources/docker-volumes/wazuh_wazuh_api_configuration/_data",
  ]
}

variable "backup_schedule_cron" {
  description = "Backrest cron (6-field). Default 02:00 UTC daily."
  type        = string
  default     = "0 0 2 * * *"
}

variable "backup_retention" {
  description = "Restic retention policy."
  type = object({
    hourly  = optional(number)
    daily   = optional(number)
    weekly  = optional(number)
    monthly = optional(number)
    yearly  = optional(number)
  })
  default = {
    daily   = 7
    weekly  = 4
    monthly = 12
    yearly  = 1
  }
}
