# monitoring-agent

Deploys the per-host monitoring stack:

- **node-exporter** — Prometheus system metrics (`:9100`).
- **cAdvisor** — Prometheus container metrics (`:8080`).
- **Grafana Alloy** — Optional log shipper that tails Docker container logs and `/var/log/{syslog,auth.log}` and forwards to Loki (`127.0.0.1:12345`).

The role is backend-agnostic: it doesn't assume a specific Prometheus, Loki, or vendor SaaS. Set the `monitoring_loki_push_url` and optionally configure your central Prometheus to scrape the exporters.

## Required variables

| Variable | Purpose |
|----------|---------|
| `monitoring_host_label` | Unique per-host label applied to every metric/log. Asserted on. |

## Recommended variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `monitoring_environment` | `production` | Logical env label (`production` \| `staging` \| `dev`). |
| `monitoring_loki_push_url` | `""` | Loki push endpoint. Empty = Alloy collects but doesn't ship logs. |
| `monitoring_prometheus_remote_write_url` | `""` | Optional Prometheus remote_write target. |
| `monitoring_scraper_cidrs` | `[]` | List of CIDRs UFW will allow to reach the exporter ports. Empty = no UFW rules added. |

## Other variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `monitoring_agent_enable_alloy` | `true` | Toggle the Alloy log shipper. |
| `monitoring_agent_alloy_log_level` | `warn` | `error` \| `warn` \| `info` \| `debug`. |
| `node_exporter_port` | `9100` | Bound on all interfaces; firewall to taste. |
| `cadvisor_port` | `8080` | Same. |
| `alloy_port` | `12345` | Bound on 127.0.0.1 only. |
| `monitoring_agent_dir` | `/opt/monitoring-agent` | Install dir. |
| `monitoring_agent_network` | `monitoring` | External docker network name. |
| `monitoring_agent_*_image` | upstream `:latest` | Image pins per component. |

## Dependencies

- `docker` role.
- `community.docker` + `community.general` collections.

## Usage

```yaml
- hosts: all
  become: true
  roles:
    - role: docker
    - role: monitoring-agent
      vars:
        monitoring_host_label: "tools-prod"
        monitoring_environment: "production"
        monitoring_loki_push_url: "https://loki.example.org/loki/api/v1/push"
        monitoring_scraper_cidrs:
          - "10.0.0.5/32"      # central Prometheus
```
