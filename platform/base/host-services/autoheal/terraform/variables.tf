# ── Contract inputs ─────────────────────────────────────────────────────────

variable "enabled" {
  description = "Master toggle. When false the bundle provisions zero resources."
  type        = bool
  default     = false
}

variable "base" {
  description = "Outputs from module \"base\". Autoheal only uses deployment_host_key; the full base object is taken for shape parity."
  type        = any
}

variable "deployment_host_key" {
  description = "Key in base.compute.hosts identifying the VM this Autoheal instance runs on. Autoheal is one-per-host: a single container watches every sibling container's healthcheck status and restarts any that go unhealthy. Instantiate this module once per host you want self-healing on."
  type        = string
  default     = "apps"
}

# ── Autoheal-specific inputs ────────────────────────────────────────────────

variable "image" {
  description = "Autoheal Docker image (without tag)."
  type        = string
  default     = "willfarrell/autoheal"
}

variable "image_tag" {
  description = "Autoheal Docker image tag."
  type        = string
  default     = "latest"
}

variable "container_label" {
  description = "Containers must carry this label set to `true` to be eligible for restart. Default `autoheal` matches what app bundles set from their own `autoheal_enabled` knob. Set to `all` to monitor every healthchecked container on the host (much more permissive)."
  type        = string
  default     = "autoheal"
}

variable "interval_seconds" {
  description = "How often Autoheal polls Docker for unhealthy containers. 5s is the upstream default and works well; bump up to reduce CPU if you have hundreds of containers, down for faster recovery if you have a few."
  type        = number
  default     = 5
}

variable "start_period_seconds" {
  description = "Grace period after a container starts during which Autoheal won't restart it even if unhealthy. Lets slow-booting containers (Decidim, Nextcloud first-install) finish migration before triggering."
  type        = number
  default     = 60
}

variable "timezone" {
  description = "IANA timezone for the container. Affects log timestamps only."
  type        = string
  default     = "UTC"
}
