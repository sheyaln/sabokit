# Per-role security groups — the coarse network-edge boundary (V1.0-PLAN "the
# one non-data edge"). One SG per role carrying a STATIC inbound superset, set
# once at infra apply and unchanged when a consumer toggles an app. The precise
# per-app gate is host `ufw`, owned by each app/ops layer (bundles'
# required_inbound_rules drive their own ufw, not this). Stateful → outbound and
# return traffic auto-permitted; only inbound is declared.
#
# One SG per distinct role in compute_hosts. Canonical roles (apps/identity/ops)
# get their port superset; any other role gets the 22/80/443 baseline. Consumers
# append per-role via var.extra_inbound_rules_by_role.

locals {
  _sg_roles = distinct([for _, h in var.compute_hosts : h.role])

  # VPC CIDR for in-cluster ingestion (Alloy push, wazuh agents). 0.0.0.0/0 only
  # when no explicit subnet is set (single-host / no managed Postgres).
  _sg_vpc = var.private_network_subnet != null ? var.private_network_subnet : "0.0.0.0/0"

  # Public baseline every role gets: SSH + Traefik (HTTP/HTTPS incl. HTTP/3 UDP 443).
  _sg_baseline = [
    { protocol = "TCP", port = 22, port_range = "22-22", ip_range = "0.0.0.0/0" },
    { protocol = "TCP", port = 80, port_range = "80-80", ip_range = "0.0.0.0/0" },
    { protocol = "TCP", port = 443, port_range = "443-443", ip_range = "0.0.0.0/0" },
    { protocol = "UDP", port = 443, port_range = "443-443", ip_range = "0.0.0.0/0" },
  ]

  # apps role: + jitsi JVB media + nextcloud Talk TURN/relay. Public — external
  # WebRTC/TURN clients initiate to the host; these don't go through Traefik.
  _sg_apps_extra = [
    { protocol = "UDP", port = 10000, port_range = "10000-10000", ip_range = "0.0.0.0/0" },
    { protocol = "TCP", port = 3478, port_range = "3478-3478", ip_range = "0.0.0.0/0" },
    { protocol = "UDP", port = 3478, port_range = "3478-3478", ip_range = "0.0.0.0/0" },
    { protocol = "UDP", port = null, port_range = "49152-49252", ip_range = "0.0.0.0/0" },
  ]

  # ops role: + log/metric ingestion (Alloy push) + wazuh-manager. VPC-scoped —
  # every source (app/identity Alloy, per-host wazuh agents) is in-VPC.
  _sg_ops_extra = [
    { protocol = "TCP", port = 3100, port_range = "3100-3100", ip_range = local._sg_vpc },
    { protocol = "TCP", port = 9090, port_range = "9090-9090", ip_range = local._sg_vpc },
    { protocol = "TCP", port = 1514, port_range = "1514-1514", ip_range = local._sg_vpc },
    { protocol = "TCP", port = 1515, port_range = "1515-1515", ip_range = local._sg_vpc },
    { protocol = "UDP", port = 514, port_range = "514-514", ip_range = local._sg_vpc },
  ]

  role_inbound = {
    for role in local._sg_roles : role => concat(
      local._sg_baseline,
      role == "apps" ? local._sg_apps_extra : [],
      role == "ops" ? local._sg_ops_extra : [],
      try(var.extra_inbound_rules_by_role[role], []),
    )
  }
}

module "role_sg" {
  source   = "../../_shared/infrastructure/security_group"
  for_each = local.role_inbound

  name          = "${local.name_suffix}-${each.key}"
  description   = "${var.org_slug} ${var.environment} ${each.key}-role SG — static inbound superset (stateful; precise per-app gating is host ufw)"
  inbound_rules = each.value
}
