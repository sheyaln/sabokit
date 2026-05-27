# platform/core/

Core-tier bundles. The monitoring/SIEM stack every consumer gets by default — logs, metrics, dashboards, alerts, host security telemetry.

Sibling to `platform/base/`, `platform/identity/`, `platform/bootstrap/`, `platform/apps/`. Consumers wire bundles here via `var.core.<svc>` — see `consumer-template/modules/stack/core.tf`.

See `ARCHITECTURE.md` for the full tier rationale.

## Tier philosophy

The category is non-optional: every consumer needs a place where logs, metrics, dashboards, and alerts land. Each individual service is flippable via `var.core.<svc>.enabled` (default `true`) for the rare consumer who already runs an external Loki, ships metrics to managed Prometheus, etc.

Defaults are production-grade: every service on, deployed to the `management` host. Override `deployment_host_key` per-service to colocate or split across hosts.

## Bundles

| Bundle | Role | Default port (private) | Notes |
|--------|------|------------------------|-------|
| `loki` | Log aggregation. Receives pushes from the base monitoring-agent (Alloy/Promtail). | 3100 | Push URL surfaced as `module.core.loki.push_url`; base monitoring-agent role consumes it. |
| `prometheus` | Metric scraping + alert evaluation. Bundled blackbox exporter probes every public hostname. Optional Scaleway TEM exporter for outbound-mail metrics. | 9090 | Auto-consumes every app's `monitoring.prometheus_scrape_configs` + `alert_rules` + `blackbox_targets`. |
| `grafana` | Dashboards + alert routing. Provisions datasources for Prometheus + Loki on the same host. Optional JSM contact point for alert paging. | https://&lt;hostname&gt; | Auto-consumes every app's `monitoring.grafana_dashboards`. |
| `wazuh` | SIEM manager + indexer + dashboard. Receives events from per-host wazuh-agents. | https://&lt;hostname&gt;; 1514/1515 tcp + 514 udp inbound | Agent runs as a per-host watcher under `platform/base/host-services/`. Manager private IP surfaced as `module.core.wazuh.manager_private_ip` for agent wiring. |

## Alerting story

Alerting itself isn't a separate bundle. It lives inside grafana (unified alerting) and prometheus (alertmanager-compatible rules).

Delivery: alerts emit as webhooks + email via base's Scaleway TEM (always available). `n8n` stays an apps-tier bundle; consumers who want webhook-driven fan-out (Slack, Discord, etc.) subscribe n8n to grafana's contact-point webhook out-of-band.

Optional JSM (heritage Opsgenie) integration: set `var.core.grafana.jsm_api_key_secret_id` and grafana provisions a `jsm-default` contact point routing every firing alert to JSM.

## Consumer wiring

```hcl
# terraform.tfvars
core = {
  loki = {
    enabled   = true
    retention = "744h"
  }
  prometheus = {
    enabled            = true
    retention          = "30d"
    tem_exporter_enabled = true
  }
  grafana = {
    enabled  = true
    hostname = "grafana.example.org"
  }
  wazuh = {
    enabled  = true
    hostname = "wazuh.example.org"
  }
}
```

## Per-bundle docs

Per-service variable surface and ansible role contract live in each bundle's `README.md`. The composition module at `platform/core/terraform/` wires them together with the right defaults; consumers don't instantiate sub-bundles directly.
