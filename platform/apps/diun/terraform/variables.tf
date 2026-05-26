# ── Contract inputs (every app bundle has these) ────────────────────────────

variable "enabled" {
  description = "Master toggle. When false the bundle provisions zero resources."
  type        = bool
  default     = false
}

variable "base" {
  description = "Outputs from module \"base\". Diun consumes only the deployment_host_key target; the full base object is taken for shape parity with other bundles."
  type        = any
}

variable "deployment_host_key" {
  description = "Key in base.compute.hosts identifying the VM this Diun instance runs on. Diun is one-per-host: a single container watches every other container on that host, polls their image registries, and notifies when a newer digest exists. Convention is to run on the management host; instantiate this module once per host you want notification coverage on."
  type        = string
  default     = "management"
}

# ── Diun-specific inputs ────────────────────────────────────────────────────

variable "instance_name" {
  description = "Per-instance name suffix. Empty default = single-instance — most consumers run one Diun per fleet. Set to a host-scoped name (e.g. \"apps\", \"management\") when running multiple instances under the same base so container/resource names don't collide. Lowercase letters, digits and hyphens only."
  type        = string
  default     = ""

  validation {
    condition     = var.instance_name == "" || can(regex("^[a-z0-9][a-z0-9-]{0,30}[a-z0-9]?$", var.instance_name))
    error_message = "instance_name must be empty or 1-32 chars, lowercase letters/digits/hyphens, not starting or ending with a hyphen."
  }
}

variable "image_tag" {
  description = "Diun Docker image tag. Pinned default reflects the upstream release crazy-max/diun verified at bundle introduction; bump deliberately."
  type        = string
  default     = "4.31.0"
}

variable "timezone" {
  description = "IANA timezone for the container. Affects log timestamps and cron-schedule interpretation."
  type        = string
  default     = "UTC"
}

variable "diun_watch_enabled" {
  description = "Whether Diun watches this Diun container for upstream image updates. Default false — auto-bumping the tool whose job is to gate image updates defeats the point. Bump it manually after reviewing the upstream changelog."
  type        = bool
  default     = false
}

variable "autoheal_enabled" {
  description = "Whether the Autoheal bundle (if deployed) restarts Diun when its healthcheck fails. Default true."
  type        = bool
  default     = true
}

variable "watch_schedule" {
  description = "Cron expression governing how often Diun polls registries for new image versions. Six-field cron (seconds first). Default daily at 06:00 UTC; tune per registry rate-limits and how quickly you want to hear about new images."
  type        = string
  default     = "0 0 6 * * *"
}

variable "watch_workers" {
  description = "Number of concurrent image-check workers. Diun's upstream default is 10; raise for large fleets, lower if you're getting registry rate-limited."
  type        = number
  default     = 10
}

variable "watch_first_check_notif" {
  description = "If true, send notifications for images Diun has never checked before (i.e. on first boot it'll flood with one notification per running container). Default false — suppress the first-boot flood; start notifying only when a digest actually changes."
  type        = bool
  default     = false
}

variable "watch_by_default" {
  description = "If true (default), Diun watches every container on the host without needing a per-container opt-in label. Set false to require `diun.enable=true` labels on containers you want watched. Default true matches the bundle's plug-and-play philosophy — opting in every app bundle by label is consumer toil we don't impose."
  type        = bool
  default     = true
}

variable "default_watch_repo" {
  description = "If true, Diun watches ALL tags of every image (heavy on registries; useful when you want to know about every new release). If false (default), only the exact tag currently in use — \"tell me when MY tag has a new digest\", which is what most consumers want."
  type        = bool
  default     = false
}

variable "include_swarm_services" {
  description = "Enable Diun's docker-swarm-mode service discovery. Default false — sabokit does not ship Swarm."
  type        = bool
  default     = false
}

variable "notification_targets" {
  description = "Legacy list-shaped notifier config kept for backwards compatibility with pre-v3.2 consumers. Each entry is `{ type = string, config = map(any) }`. New consumers should use `n8n_webhook_url` (auto-derived from the n8n bundle) plus `diun_notif_extra` (map keyed by notifier type) instead. Empty default."
  type        = list(any)
  default     = []
  sensitive   = true
}

variable "n8n_webhook_url" {
  description = "Webhook URL Diun POSTs new-image events to. The consumer-template auto-derives this from `module.n8n.app_url` + `/webhook/diun-image-update` when the n8n bundle is enabled. Empty default means no webhook target is added; Diun runs but stays dormant unless `notification_targets` or `diun_notif_extra` supply a target. Override here to point at a non-n8n receiver."
  type        = string
  default     = ""
}

variable "diun_notif_extra" {
  description = "Extra notification providers, keyed by Diun notifier type (slack, mail, discord, telegram, teams, matrix, gotify, ntfy, opsgenie, pushover, rocketchat, script, twilio, amqp, mqtt). Each value is passed through verbatim to that notifier's block under `notif:` in diun.yml. Shape mirrors https://crazymax.dev/diun/notif/ — e.g. `{ slack = { webhook_url = \"...\" }, mail = { host = \"...\", port = 587, ... } }`. Lets consumers add channels alongside the auto-wired n8n webhook without forking the bundle."
  type        = map(any)
  default     = {}
  sensitive   = true
}

variable "monitoring_enabled" {
  description = "If true and a monitoring app is enabled, Diun's container log paths wire into Loki. Diun does not expose Prometheus metrics natively (a separate `crazy-max/diun-exporter` exists upstream but is experimental and not wired here)."
  type        = bool
  default     = true
}
