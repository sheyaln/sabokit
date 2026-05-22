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
  description = "Allow inbound SSH (TCP 22) from anywhere."
  type        = bool
  default     = true
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
