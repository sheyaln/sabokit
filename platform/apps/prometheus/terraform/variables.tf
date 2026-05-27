# ── Contract inputs ─────────────────────────────────────────────────────────

variable "enabled" {
  description = "Master toggle. When false the bundle provisions zero resources."
  type        = bool
  default     = false
}

variable "base" {
  description = "Outputs from module \"base\". Prometheus only consumes the deployment_host_key target; the full base object is taken for shape parity."
  type        = any
}

variable "deployment_host_key" {
  description = "Key in base.compute.hosts identifying the VM this Prometheus instance runs on. Typically your `management` or `monitoring` host."
  type        = string
  default     = "management"
}

# ── Prometheus-specific inputs ──────────────────────────────────────────────

variable "image" {
  description = "Prometheus Docker image (without tag)."
  type        = string
  default     = "prom/prometheus"
}

variable "image_tag" {
  description = "Prometheus Docker image tag. Pin in production."
  type        = string
  default     = "latest"
}

variable "retention" {
  description = "TSDB retention window. Accepts Prometheus duration syntax (15d, 90d, 1y). Storage scales linearly with this and the sample rate."
  type        = string
  default     = "30d"
}

variable "scrape_configs" {
  description = "Additional scrape_configs entries to merge into prometheus.yml beyond the bundle's defaults (prometheus self-scrape + node-exporter if `exporters_enabled = true`). Consumer-template aggregates each app bundle's `monitoring.prometheus_scrape_configs` into this. Pass as a list of objects matching Prometheus's scrape_config schema."
  type        = list(any)
  default     = []
}

variable "alert_rules" {
  description = "List of alerting rules to render into Prometheus's rules.yml. Consumer-template aggregates each app's `monitoring.alert_rules` into this. Pass as a list of groups, each `{ name = string, rules = list({...}) }`."
  type        = list(any)
  default     = []
}

variable "exporters_enabled" {
  description = "Whether to deploy node_exporter + cadvisor alongside Prometheus on the same host as default scrape targets. Default true — host + container metrics are the common scrape baseline."
  type        = bool
  default     = true
}

variable "remote_write_enabled" {
  description = "Whether to enable Prometheus's remote-write receiver endpoint (POST /api/v1/write). Useful when external services push metrics into Prometheus instead of being scraped. Default true."
  type        = bool
  default     = true
}

variable "extra_scrape_targets" {
  description = "Extra Prometheus scrape jobs as `job_name → list(target_endpoint)`. Each entry becomes a scrape_config with a single static_configs targets list. Typical use: cross-host base-exporter scrapes (node_exporter, cadvisor, traefik metrics on every infra host) when the management host needs to scrape over the VPC. Consumer-template doesn't auto-aggregate this — supply directly from your host inventory."
  type        = map(list(string))
  default     = {}
}

variable "blackbox_exporter_enabled" {
  description = "Deploy the bundled Prometheus Blackbox Exporter sidecar — actively probes URLs over HTTP(S)/TCP/ICMP and exposes probe_success, probe_http_status_code, probe_ssl_earliest_cert_expiry, probe_duration_seconds. Default true; opt-out. Consumer-aggregated `blackbox_targets` from every enabled bundle plus this module's `blackbox_targets` input are rendered into a Prometheus file_sd target list. Sidecar is internal-only (monitoring_internal network, port 9115)."
  type        = bool
  default     = true
}

variable "blackbox_exporter_image_tag" {
  description = "blackbox_exporter image tag. Pin in production."
  type        = string
  default     = "v0.28.0"
}

variable "blackbox_targets" {
  description = "Extra probe targets beyond the consumer-aggregated set (e.g. probe an external dependency you care about). Each entry is a full URL. Default empty."
  type        = list(string)
  default     = []
}

variable "tem_exporter_enabled" {
  description = "Deploy the bundled Scaleway TEM exporter sidecar (Python; polls Scaleway's TEM API and exposes /metrics on port 9111). Pair with the bundled `scaleway-tem` dashboard + alert rules. Requires `tem_smtp_secret_id` so the role can pull the TEM-scoped API key out of Scaleway Secret Manager (the SMTP password from base's smtp-config secret IS that key)."
  type        = bool
  default     = false
}

variable "tem_smtp_secret_id" {
  description = "Scaleway secret ID for the smtp-config secret (typically `module.base.scaleway.smtp_config_secret_id`). Only consumed when `tem_exporter_enabled = true`. The exporter unwraps it and uses the `password` field as the TEM API key."
  type        = string
  default     = ""
}

variable "tem_scaleway_project_id" {
  description = "Scaleway project ID scoping the TEM API queries (typically `var.base_scaleway_project_id`). Only consumed when `tem_exporter_enabled = true`."
  type        = string
  default     = ""
}

variable "tem_scaleway_region" {
  description = "Scaleway region the TEM domain lives in. Only consumed when `tem_exporter_enabled = true`."
  type        = string
  default     = "fr-par"
}

variable "tem_exporter_poll_interval_seconds" {
  description = "How often the TEM exporter polls Scaleway's API. Lower = fresher metrics + higher API quota usage."
  type        = number
  default     = 60
}

variable "tem_exporter_lookback_minutes" {
  description = "Rolling window the TEM exporter uses for per-flag / per-status counts (drives bounce-rate, spam-rate etc.). Match this to the alert `for:` durations + Grafana panel time range."
  type        = number
  default     = 60
}

variable "private_ip_bind" {
  description = "Optional host private IP to bind Prometheus's port 9090 to. Empty = bind to 127.0.0.1 only (internal access via Grafana or SSH tunnel). Set to a private-network IP to let other hosts on the VPC scrape directly or push via remote-write."
  type        = string
  default     = ""
}

variable "memory_limit" {
  description = "Container memory ceiling. Prometheus's working set scales with active series count + retention; default fits ~100k series at 30d."
  type        = string
  default     = "2G"
}

variable "memory_reservation" {
  description = "Container memory reservation."
  type        = string
  default     = "512M"
}

variable "cpu_limit" {
  description = "Container CPU ceiling."
  type        = string
  default     = "2.0"
}

variable "cpu_reservation" {
  description = "Container CPU reservation."
  type        = string
  default     = "0.5"
}

variable "timezone" {
  description = "IANA timezone for the container (log timestamps)."
  type        = string
  default     = "UTC"
}

variable "diun_watch_enabled" {
  description = "Whether Diun watches this app's containers for upstream image updates. When true (default) the bundle emits a `diun.enable=true` label on each compose service, opting it into the platform Diun bundle's registry polling. Flip false to silence notifications for this app."
  type        = bool
  default     = true
}

variable "autoheal_enabled" {
  description = "Whether the Autoheal platform bundle (if deployed) restarts Prometheus when its healthcheck fails. Default true."
  type        = bool
  default     = true
}

variable "backup_enabled" {
  description = "Whether the Backrest platform bundle (if deployed) backs up Prometheus's TSDB. Default true — losing the TSDB means losing all historical metrics."
  type        = bool
  default     = true
}

variable "backup_extra_paths" {
  description = "Additional restic paths beyond `/backup-sources/opt/prometheus`. The TSDB lives in the named volume `prometheus_prometheus-data` — by default the volume is included via `/backup-sources/docker-volumes/prometheus_prometheus-data/_data`."
  type        = list(string)
  default     = ["/backup-sources/docker-volumes/prometheus_prometheus-data/_data"]
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

variable "extra_env_vars" {
  description = "Map of KEY → value rendered into the container .env after first-class vars. Use for env-driven feature flags / third-party integrations / debug toggles not exposed first-class on the bundle."
  type        = map(string)
  default     = {}
}

variable "extra_docker_networks" {
  description = "Extra docker networks to attach the bundle's main container to alongside its traefik network. Networks must already exist on the host. Use for cross-bundle integration with sidecars in other bootstrap-tier networks."
  type        = list(string)
  default     = []
}

