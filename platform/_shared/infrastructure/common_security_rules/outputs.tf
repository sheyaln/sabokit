output "inbound_rules" {
  description = "Combined list of inbound rules from all enabled bundles. Feed directly into a scaleway/security_group module's inbound_rules input, or concat with consumer-specific extras."
  value = concat(
    local.https_rules,
    local.http_rules,
    local.ssh_rules,
    local.dns_rules,
    local.turn_stun_rules,
    local.wazuh_manager_rules,
    local.monitoring_rules,
  )
}
