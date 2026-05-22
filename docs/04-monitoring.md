---
layout: default
title: "Part 4: Monitoring"
---

# Part 4: Monitoring & Observability

Monitoring runs on the management server. It collects metrics and logs from all servers.

## 4.1 Components

- **Grafana**: Dashboards and visualization
- **Prometheus**: Metrics storage and querying
- **Loki**: Log aggregation
- **Zabbix**: Infrastructure monitoring
- **Alloy**: Log shipper (runs on each server)
- **Node Exporter**: Host metrics (runs on each server)
- **cAdvisor**: Container metrics (runs on each server)

## 4.2 Architecture

```
tools-prod ──────┐
                 │  metrics (9100, 8080)
                 ├──────────────────────────► management
authentik-prod ──┤                              ├── Prometheus
                 │  logs (3100)                 ├── Loki
                 └──────────────────────────►   ├── Grafana
                                                └── Zabbix
```

Prometheus scrapes metrics from all servers via private network.
Alloy pushes logs to Loki on management server.

## 4.3 Deployment

### Monitoring Stack (Management Server)

```bash
ansible-playbook playbook-management.yml -i inventory.ini --tags monitoring-stack
```

Deploys Grafana, Prometheus, Loki, Zabbix.

### Exporters (All Servers)

```bash
ansible-playbook playbook-tools-prod.yml -i inventory.ini --tags monitoring-exporters
ansible-playbook playbook-authentik.yml -i inventory.ini --tags monitoring-exporters
```

Deploys Node Exporter, cAdvisor, Alloy.

## 4.4 Configuration Files

### Monitoring Stack

Location: `roles/monitoring/stack/`

Files deployed:
- `/opt/monitoring/docker-compose.yml`
- `/opt/monitoring/.env`
- `/opt/monitoring/prometheus/prometheus.yml`
- `/opt/monitoring/loki/loki-config.yml`
- `/opt/monitoring/grafana/provisioning/datasources/datasources.yml`

### Exporters

Location: `roles/monitoring/exporters/`

Files deployed:
- `/opt/exporters/docker-compose.yml`
- `/opt/exporters/alloy-config.yaml`

## 4.5 Ports

| Service | Port | Access |
|---------|------|--------|
| Grafana | 3000 | Via Traefik (grafana.example.cc) |
| Prometheus | 9090 | Internal only |
| Loki | 3100 | Internal (private network) |
| Zabbix Web | 8080 | Via Traefik (zabbix.example.cc) |
| Zabbix Server | 10051 | Internal |
| Node Exporter | 9100 | Private network |
| cAdvisor | 8080 | Private network |

## 4.6 Grafana

URL: https://grafana.example.cc

Authentication via Authentik SSO. Role mapping:
- admin group: Admin role
- union-delegate group: Editor role
- Others: Viewer role

### Terraform Grafana

`terraform-grafana/` manages:
- Dashboard folders
- Dashboard JSON files
- Folder permissions

```bash
cd terraform-grafana
terraform apply
```

### Dashboards

Located in `terraform-grafana/dashboards/`:
- infrastructure-overview.json
- traefik-overview.json
- tools-prod-application-stack.json
- authentik-metrics.json
- logs-explorer.json

## 4.7 Prometheus

Scrape configuration in `roles/monitoring/stack/templates/prometheus.yml.j2`:

```yaml
scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'node-exporter-management'
    static_configs:
      - targets: ['{% raw %}{{ server_ips.management }}{% endraw %}:9100']

  - job_name: 'node-exporter-tools-prod'
    static_configs:
      - targets: ['{% raw %}{{ server_ips["tools-prod"] }}{% endraw %}:9100']

  - job_name: 'node-exporter-authentik'
    static_configs:
      - targets: ['{% raw %}{{ server_ips.authentik }}{% endraw %}:9100']

  - job_name: 'cadvisor-management'
    static_configs:
      - targets: ['{% raw %}{{ server_ips.management }}{% endraw %}:8080']

  # ...
```

Retention: 15 days (configurable in group-vars/monitoring.yml)

## 4.8 Loki

Receives logs from all servers via Alloy.

Push URL: `http://{management-private-ip}:3100/loki/api/v1/push`

Retention: 7 days (168h)

Configuration in `roles/monitoring/stack/templates/loki-config.yml.j2`

## 4.9 Alloy (Log Shipper)

Runs on each server. Reads Docker container logs and ships to Loki.

Configuration in `roles/monitoring/exporters/templates/alloy-config.yaml.j2`:

```yaml
loki.write "default" {
  endpoint {
    url = "{% raw %}{{ loki_push_url }}{% endraw %}"
  }
}

loki.source.docker "docker" {
  host = "unix:///var/run/docker.sock"
  targets = discovery.docker.containers.targets
  forward_to = [loki.write.default.receiver]
  labels = {
    server = "{% raw %}{{ server_name }}{% endraw %}",
    env = "{% raw %}{{ environment_type }}{% endraw %}",
  }
}
```

## 4.10 Zabbix

URL: https://zabbix.example.cc

Uses managed PostgreSQL database.

Credentials in Scaleway Secret Manager: `postgres-zabbix-credentials`

Components:
- Zabbix Server
- Zabbix Web (nginx frontend)
- Zabbix Agent (on each server)

## 4.11 Group Variables

`group-vars/monitoring.yml`:

```yaml
monitoring_domain: "example.cc"

server_ips:
  management: "10.0.0.5"    # Your management private IP
  tools-prod: "10.0.0.3"    # Your tools-prod private IP
  authentik: "10.0.0.2"     # Your authentik private IP

loki_push_url: "http://{% raw %}{{ server_ips.management }}{% endraw %}:3100/loki/api/v1/push"

prometheus_retention: "15d"
loki_retention: "168h"

exporter_ports:
  node_exporter: 9100
  cadvisor: 8080
  alloy: 12345

grafana_oauth_client_id: "{% raw %}{{ (lookup('scaleway.scaleway.scaleway_secret', 'authentik-app-grafana') | b64decode | from_json).client_id }}{% endraw %}"
grafana_oauth_client_secret: "{% raw %}{{ (lookup('scaleway.scaleway.scaleway_secret', 'authentik-app-grafana') | b64decode | from_json).client_secret }}{% endraw %}"
```

## 4.12 Adding a Server to Monitoring

1. Add server IP to `group-vars/monitoring.yml` under `server_ips`

2. Add scrape targets in `roles/monitoring/stack/templates/prometheus.yml.j2`

3. Update UFW rules in `roles/monitoring/stack/tasks/main.yml`

4. Deploy exporters to new server

5. Redeploy monitoring stack:
```bash
ansible-playbook playbook-management.yml -i inventory.ini --tags monitoring-stack
```

## 4.13 Viewing Logs

In Grafana:
1. Go to Explore
2. Select Loki datasource
3. Query: `{server="tools-prod", container="outline"}`

Common queries:
```logql
# All logs from a container
{container="outline"}

# Error logs
{server="tools-prod"} |= "error"

# Specific time range
{container="traefik"} | json | status >= 400
```

## 4.14 Viewing Metrics

In Grafana:
1. Go to Explore
2. Select Prometheus datasource
3. Query: `node_cpu_seconds_total{instance="10.0.0.3:9100"}`

Common queries:
```promql
# CPU usage
100 - (avg by(instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)

# Memory usage
(1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) * 100

# Disk usage
(1 - node_filesystem_avail_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"}) * 100

# Container memory
container_memory_usage_bytes{name=~".+"}
```
