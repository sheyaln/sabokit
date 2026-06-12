variable "enable_https" {
  description = "Allow inbound HTTPS (TCP+UDP 443) from anywhere. UDP 443 carries HTTP/3."
  type        = bool
  default     = true
}

variable "enable_http" {
  description = "Allow inbound HTTP (TCP 80) from anywhere. Needed for Let's Encrypt HTTP-01 challenge and 80-to-443 redirect."
  type        = bool
  default     = true
}

variable "enable_ssh" {
  description = "Allow inbound SSH (TCP 22)."
  type        = bool
  default     = true
}

variable "ssh_cidr" {
  description = "Source CIDR allowed to reach SSH (TCP 22) when enable_ssh is true. Defaults to anywhere for first-boot reachability; scope to an admin/bastion CIDR for a hardened fleet. Key-only auth + fail2ban still apply regardless."
  type        = string
  default     = "0.0.0.0/0"
}

variable "wazuh_manager_cidr" {
  description = "Source CIDR allowed to reach the Wazuh manager ports (1514/1515/514) when enable_wazuh_manager is true. Defaults to anywhere; scope to the fleet's egress/public IPs. Enrollment also requires a password (authd use_password=yes), so this is defence-in-depth, not the only control."
  type        = string
  default     = "0.0.0.0/0"
}

variable "enable_dns" {
  description = "Allow inbound DNS (TCP+UDP 53). Only needed for hosts running a public DNS resolver."
  type        = bool
  default     = false
}

variable "enable_turn_stun" {
  description = "Allow inbound TURN/STUN ports (TCP+UDP 3478 + UDP 49152-49252) for Nextcloud Talk / WebRTC relays."
  type        = bool
  default     = false
}

variable "enable_wazuh_manager" {
  description = "Allow inbound ports for hosting a Wazuh manager (TCP 1514, TCP 1515, UDP 514)."
  type        = bool
  default     = false
}

variable "monitoring_cidr" {
  description = "If non-null, allow Node Exporter (9100), cAdvisor (8080), and Promtail (9080) from this CIDR only. Typically the management host's private IP. null = no monitoring rules."
  type        = string
  default     = null
}
