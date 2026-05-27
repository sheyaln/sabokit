# Per-host auto-instantiation of host-services bundles. One module call per
# entry in var.compute_hosts, gated by var.base.<service>.enabled +
# disabled_hosts. Empty in v3.4.0-prep (Ticket 1); populated as tickets 2-4
# land each service.
