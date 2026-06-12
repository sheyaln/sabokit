locals {
  https_rules = var.enable_https ? [
    { protocol = "TCP", port = 443, port_range = "443-443", ip_range = "0.0.0.0/0" },
    { protocol = "UDP", port = 443, port_range = "443-443", ip_range = "0.0.0.0/0" },
  ] : []

  http_rules = var.enable_http ? [
    { protocol = "TCP", port = 80, port_range = "80-80", ip_range = "0.0.0.0/0" },
  ] : []

  ssh_rules = var.enable_ssh ? [
    { protocol = "TCP", port = 22, port_range = "22-22", ip_range = var.ssh_cidr },
  ] : []

  dns_rules = var.enable_dns ? [
    { protocol = "TCP", port = 53, port_range = "53-53", ip_range = "0.0.0.0/0" },
    { protocol = "UDP", port = 53, port_range = "53-53", ip_range = "0.0.0.0/0" },
  ] : []

  turn_stun_rules = var.enable_turn_stun ? [
    { protocol = "TCP", port = 3478, port_range = "3478-3478", ip_range = "0.0.0.0/0" },
    { protocol = "UDP", port = 3478, port_range = "3478-3478", ip_range = "0.0.0.0/0" },
    { protocol = "UDP", port = null, port_range = "49152-49252", ip_range = "0.0.0.0/0" },
  ] : []

  wazuh_manager_rules = var.enable_wazuh_manager ? [
    { protocol = "TCP", port = 1514, port_range = "1514-1514", ip_range = var.wazuh_manager_cidr },
    { protocol = "TCP", port = 1515, port_range = "1515-1515", ip_range = var.wazuh_manager_cidr },
    { protocol = "UDP", port = 514, port_range = "514-514", ip_range = var.wazuh_manager_cidr },
  ] : []

  monitoring_rules = var.monitoring_cidr == null ? [] : [
    { protocol = "TCP", port = 9100, port_range = "9100-9100", ip_range = var.monitoring_cidr },
    { protocol = "TCP", port = 8080, port_range = "8080-8080", ip_range = var.monitoring_cidr },
    { protocol = "TCP", port = 9080, port_range = "9080-9080", ip_range = var.monitoring_cidr },
  ]
}
