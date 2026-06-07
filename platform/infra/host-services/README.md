# platform/infra/host-services/

Host-tier services - one instance per compute_host. Each watches/touches state local to its own host:

- `diun/` - notify-on-new-image watcher (one per host, default-on)
- `autoheal/` - container-restart-on-unhealthy watchdog (one per host, default-on)
- `wazuh-agent/` - log shipper to wazuh manager (one per host, default-on; consumers without a manager set `enabled = false` or list every host in `disabled_hosts`)

Each service is default-on. Consumers turn services off via `var.base.<service>.enabled = false` (whole service) or `disabled_hosts` (per-host opt-out).

Auto-instantiated by `platform/infra/terraform/host_services.tf` via `for_each` over `var.compute_hosts`.

Consumer surface is `var.base.<service>.{enabled, disabled_hosts, per_host, ...}`. See ARCHITECTURE.md.

NOT to be confused with `platform/bootstrap/` - bootstrap is shared infrastructure providers (SMTP/IMAP gateways), host-services are per-host runtime watchers.
