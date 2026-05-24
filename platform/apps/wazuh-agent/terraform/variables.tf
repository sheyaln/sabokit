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

variable "auto_update_enabled" {
  description = "Whether the Watchtower platform bundle auto-pulls newer agent images. Default FALSE — the agent's version MUST match the manager's; bump in lockstep."
  type        = bool
  default     = false
}

variable "autoheal_enabled" {
  description = "Whether the Autoheal platform bundle restarts the agent when its healthcheck fails. Default true."
  type        = bool
  default     = true
}
