# Consumed by the operations Ansible play (terraform output -json enabled_apps).

output "enabled_apps" {
  description = "Per-service dispatch map (loki/prometheus/grafana/wazuh/protonmail-bridge) the operations play deploys."
  value       = module.operations.core_apps
  sensitive   = true
}

output "loki" {
  description = "Loki handles. push_url is what the infra monitoring-agent (Alloy) remote_writes/pushes to."
  value       = module.operations.loki
}
