# ── Contract inputs (every app bundle has these) ────────────────────────────

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
  description = "Full hostname Grafana is served at (e.g. \"grafana.example.org\")."
  type        = string
  default     = ""
}

variable "category_group" {
  description = "Authentik portal category."
  type        = string
  default     = "Operations"
}

variable "application_name" {
  description = "Display name for the bundle's Authentik application (shown in the portal + admin UI). Default matches the bundle's stock name; override per-consumer for branded portal entries (e.g. \"Sabo Cloud Provider\" instead of \"Nextcloud\")."
  type        = string
  default     = "Grafana"
}

variable "application_slug" {
  description = "Override the Authentik application's slug. Defaults to the bundle's stock slug (`grafana`). Set to match an existing legacy slug to enable in-place state import without force-replace. Note: this overrides ONLY the Authentik application's slug — bucket names, secret names, IAM apps and other internal namespaces keep using the canonical bundle slug."
  type        = string
  default     = ""
}

variable "icon_url" {
  description = "Full icon URL override. When set, used verbatim and `icon_filename` is ignored. Empty string falls back to `$${base.authentik.icon_base_url}/$${icon_filename}` (or no icon when `icon_filename` is also empty)."
  type        = string
  default     = ""
}

variable "icon_filename" {
  description = "Icon filename fetched from `base.authentik.icon_base_url`. Empty disables the icon. Overridden by `icon_url`."
  type        = string
  default     = "grafana-icon.png"
}

variable "access_level" {
  description = "Key in base.authentik.groups granting baseline access. Defaults to \"admin\" — Grafana exposes alerting + data sources, treat as ops-only by default."
  type        = string
  default     = "admin"
}

variable "extra_authorized_groups" {
  description = "Additional Authentik groups allowed beyond access_level. Keys must be static strings."
  type        = map(string)
  default     = {}
}

variable "tier_cascade_enabled" {
  description = "Whether to derive authorized_groups from the platform tier cascade (member→delegate→treasurer→admin; each tier inherits all lower tiers). Default true. Set false to use the primitive access_level + extra_authorized_groups path instead."
  type        = bool
  default     = true
}

variable "tier_access_level" {
  description = "Cascade tier required for baseline access. Users in this tier and any higher tier are admitted. Only consulted when tier_cascade_enabled = true."
  type        = string
  default     = "admin"
}

variable "monitoring_enabled" {
  description = "If true and a monitoring app is enabled, Grafana's log paths wire in. No effect when monitoring apps are disabled."
  type        = bool
  default     = true
}

variable "deployment_host_key" {
  description = "Key in base.compute.hosts identifying the VM this Grafana instance runs on. Typically the same as your prometheus + loki host."
  type        = string
  default     = "management"
}

# ── Grafana-specific inputs ─────────────────────────────────────────────────

variable "image" {
  description = "Grafana Docker image (without tag)."
  type        = string
  default     = "grafana/grafana"
}

variable "image_tag" {
  description = "Grafana Docker image tag. Pin in production."
  type        = string
  default     = "latest"
}

variable "admin_username" {
  description = "Bootstrap admin username. OIDC users sign in separately; this is the break-glass account."
  type        = string
  default     = "admin"
}

variable "plugins" {
  description = "List of plugins to preinstall via GF_PLUGINS_PREINSTALL. Comma-joined into the env var at render time."
  type        = list(string)
  default     = []
}

variable "oidc_admin_group" {
  description = "Authentik group name whose members are mapped to Grafana's Admin role."
  type        = string
  default     = "admin"
}

variable "oidc_editor_group" {
  description = "Authentik group name whose members are mapped to Grafana's Editor role."
  type        = string
  default     = "manager"
}

variable "prometheus_url" {
  description = "URL Grafana uses to reach Prometheus. Default `http://prometheus:9090` works when both bundles share the `monitoring_internal` docker network."
  type        = string
  default     = "http://prometheus:9090"
}

variable "loki_url" {
  description = "URL Grafana uses to reach Loki. Default `http://loki:3100` works for shared-network deployments."
  type        = string
  default     = "http://loki:3100"
}

variable "prometheus_scrape_interval" {
  description = "Scrape interval Grafana's Prometheus datasource expects. Should match the prometheus bundle's global.scrape_interval (default 30s)."
  type        = string
  default     = "30s"
}

variable "jsm_api_key_secret_id" {
  description = "Scaleway secret ID holding the JSM Operations (heritage Opsgenie) API integration key, JSON-encoded as `{ \"api_key\": \"...\" }`. Empty disables JSM provisioning entirely (default). When set, Grafana provisions a `jsm-default` contact point and routes the root notification policy to it — i.e. every firing alert pages JSM unless a child policy overrides. Existing v2.11.0 consumers stay unaffected until they fill this in."
  type        = string
  default     = ""
}

variable "jsm_api_region" {
  description = "JSM API region: `us` (default, https://api.atlassian.com/jsm/ops) or `eu` (https://api.eu.atlassian.com/jsm/ops). Pick the one your Atlassian site is in. The heritage Opsgenie URLs (api.opsgenie.com / api.eu.opsgenie.com) still work too but Atlassian recommends the jsm/ops path."
  type        = string
  default     = "us"
  validation {
    condition     = contains(["us", "eu"], var.jsm_api_region)
    error_message = "jsm_api_region must be \"us\" or \"eu\"."
  }
}

variable "jsm_priority_mapping" {
  description = "Map of Grafana alert `severity` label value -> JSM priority (P1-P5). Default maps critical/warning/info to P1/P3/P5. Override per your on-call runbook (e.g. all-P1 if you don't run severity tiers)."
  type        = map(string)
  default     = { critical = "P1", warning = "P3", info = "P5" }
}

variable "jsm_alert_tags" {
  description = "Tags attached to every alert sent to JSM. Useful for routing rules in JSM's notification policies. Default tags the alert as originating from sabokit."
  type        = list(string)
  default     = ["sabokit"]
}

variable "grafana_dashboards" {
  description = "Dashboards to provision into Grafana's file provider. The consumer reads each path from every enabled app's monitoring.grafana_dashboards (list(string) of file paths), turns it into {filename, contents}, and passes the union here. The role writes one file per entry under /etc/grafana/provisioning/dashboards/; Grafana's file provider auto-reloads (no restart needed)."
  type = list(object({
    filename = string
    contents = string
  }))
  default = []
}

variable "memory_limit" {
  description = "Container memory ceiling."
  type        = string
  default     = "1G"
}

variable "memory_reservation" {
  description = "Container memory reservation."
  type        = string
  default     = "256M"
}

variable "cpu_limit" {
  description = "Container CPU ceiling."
  type        = string
  default     = "1.0"
}

variable "cpu_reservation" {
  description = "Container CPU reservation."
  type        = string
  default     = "0.1"
}

variable "auto_update_enabled" {
  description = "Whether the Watchtower platform bundle auto-pulls newer Grafana images. Default FALSE — Grafana plugins can pin to specific Grafana versions; let Ansible drive bumps."
  type        = bool
  default     = false
}

variable "autoheal_enabled" {
  description = "Whether the Autoheal platform bundle restarts Grafana when its healthcheck fails. Default true."
  type        = bool
  default     = true
}

variable "backup_enabled" {
  description = "Whether the Backrest platform bundle backs up Grafana's SQLite + dashboards. Default true."
  type        = bool
  default     = true
}

variable "backup_extra_paths" {
  description = "Additional restic paths. Grafana's data dir is the named volume `grafana_grafana-data`."
  type        = list(string)
  default     = ["/backup-sources/docker-volumes/grafana_grafana-data/_data"]
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
