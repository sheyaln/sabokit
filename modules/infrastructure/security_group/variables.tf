variable "name" {
  description = "Security group name."
  type        = string
}

variable "description" {
  description = "Security group description."
  type        = string
  default     = ""
}

variable "inbound_rules" {
  description = "Inbound rules. Each rule: protocol (TCP|UDP|ICMP), and either a single port or a port_range, plus an ip_range (defaults to 0.0.0.0/0)."
  type = list(object({
    protocol   = string
    port       = optional(number)
    port_range = optional(string)
    ip_range   = optional(string, "0.0.0.0/0")
  }))
  default = []
}

variable "inbound_default_policy" {
  description = "Default action for inbound traffic that matches no rule."
  type        = string
  default     = "drop"
}

variable "outbound_default_policy" {
  description = "Default action for outbound traffic that matches no rule."
  type        = string
  default     = "accept"
}

variable "stateful" {
  description = "Whether the security group is stateful (return traffic for accepted flows is auto-allowed)."
  type        = bool
  default     = true
}

variable "enable_default_security" {
  description = "Whether Scaleway's default-security rules are applied. Usually false because rules are managed here."
  type        = bool
  default     = false
}
