# Core-tier composition variables. Same `any`-typed pass-through pattern the
# consumer-template uses for var.apps — each sub-service unpacks its own
# knobs from these maps via try() against the upstream bundle defaults.
# Per-service variable shape is documented in each bundle's variables.tf.

variable "base" {
  description = "Outputs from module.base (scaleway, compute, domains, authentik passthrough)."
  type        = any
}

variable "loki" {
  description = "Loki bundle knobs. See platform/core/loki/terraform/variables.tf. Defaults to {enabled = true}."
  type        = any
  default     = {}
}

variable "prometheus" {
  description = "Prometheus bundle knobs. See platform/core/prometheus/terraform/variables.tf. Defaults to {enabled = true}."
  type        = any
  default     = {}
}

variable "grafana" {
  description = "Grafana bundle knobs. See platform/core/grafana/terraform/variables.tf. Defaults to {enabled = true}."
  type        = any
  default     = {}
}

variable "wazuh" {
  description = "Wazuh-manager bundle knobs. See platform/core/wazuh/terraform/variables.tf. Defaults to {enabled = true}."
  type        = any
  default     = {}
}

# Auto-aggregated inputs the composition layer needs but each sub-bundle
# would otherwise reach across modules for. Consumer-template builds these
# from every enabled app's monitoring/backup_plan output before calling
# module.core, same way it builds the aggregated_* locals today.

variable "aggregated_scrape_configs" {
  description = "Pre-aggregated prometheus scrape entries from every enabled app's monitoring.prometheus_scrape_configs. Consumer-template emits this; the core module concats it onto var.prometheus.scrape_configs."
  type        = any
  default     = []
}

variable "aggregated_alert_rules" {
  description = "Pre-aggregated prometheus alert rules from every enabled app's monitoring.alert_rules."
  type        = any
  default     = []
}

variable "aggregated_blackbox_targets" {
  description = "Pre-aggregated blackbox exporter target list."
  type        = any
  default     = []
}

variable "aggregated_grafana_dashboards" {
  description = "Pre-aggregated dashboard files. Each entry: {filename, contents}. Consumer-template reads the source files via file()."
  type        = any
  default     = []
}
