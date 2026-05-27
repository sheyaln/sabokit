# platform/base/host-services/

Host-tier services - one instance per compute_host. Each watches/touches state local to its own host:

- `diun/` - notify-on-new-image watcher (one per host, default-on)
- `autoheal/` - container-restart-on-unhealthy watchdog (one per host, default-on)
- `wazuh-agent/` - log shipper to wazuh manager (one per host, default-off, requires manager)

Auto-instantiated by `platform/base/terraform/host_services.tf` via `for_each` over `var.compute_hosts`.

Consumer surface is `var.base.<service>.{enabled, disabled_hosts, per_host, ...}`. See ARCHITECTURE.md.

NOT to be confused with `platform/bootstrap/` - bootstrap is shared infrastructure providers (SMTP/IMAP gateways), host-services are per-host runtime watchers.
