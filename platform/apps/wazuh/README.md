# apps/wazuh

[Wazuh](https://wazuh.com) server stack — manager + indexer (OpenSearch fork) + dashboard. SIEM + endpoint detection. UI fronted by Authentik forward-auth; OIDC happens at the gateway because the Wazuh dashboard's native SSO is OpenSearch-flavoured (full OIDC needs custom `config.yml` for the opensearch-security plugin).

Agent role for monitored hosts ships separately in a follow-up tag. The bundle opens the manager's agent/enrollment/syslog ports in the host SG via `required_inbound_rules`.

## Inputs

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `enabled` | `bool` | `false` | Master toggle. |
| `base` | object | — | Outputs from `module.base`. |
| `hostname` | `string` | — (required when enabled) | Dashboard hostname. |
| `category_group` | `string` | `"Security"` | Authentik portal category. |
| `icon_url` | `string` | `null` | Optional icon. |
| `access_level` | `string` | `"admin"` | Defaults admin-only — SIEM + active response. |
| `extra_authorized_groups` | `map(string)` | `{}` | Extra groups. |
| `monitoring_enabled` | `bool` | `true` | Wire log paths into monitoring. |
| `deployment_host_key` | `string` | `"management"` | Host this manager runs on. |
| `version` | `string` | `"4.9.0"` | Wazuh release. All 3 images move in lockstep. |
| `indexer_heap_size` | `string` | `"1g"` | OpenSearch JVM heap (50% of host RAM, max 31g). |
| `manager_agent_port` | `number` | `1514` | TCP port for agent connections. |
| `manager_enrollment_port` | `number` | `1515` | TCP port for agent enrollment. |
| `manager_syslog_port` | `number` | `514` | UDP port for syslog ingestion. |
| `memory_limit` / `memory_reservation` | `string` | `"2G"` / `"512M"` | Manager container memory. |
| `cpu_limit` / `cpu_reservation` | `string` | `"2.0"` / `"0.5"` | Manager container CPU. |
| `auto_update_enabled` | `bool` | `false` | Off by default — 3 images move in lockstep + occasional index schema migration. |
| `autoheal_enabled` | `bool` | `true` | |
| `backup_enabled` | `bool` | `true` | Indexer data + manager state backed up by default. |
| `backup_extra_paths` / `backup_schedule_cron` / `backup_retention` | (see vars) | — | |

## Outputs

| Name | Description |
|------|-------------|
| `enabled` | Mirrors `var.enabled`. |
| `app_url` | `https://<hostname>` or null. |
| `authentik_provider_id` | Forward-auth provider ID. **Must** be added to identity's `extra_forward_auth_provider_ids`. |
| `authentik_application_group_id` | Per-app group `app-wazuh`. |
| `monitoring` | Log paths contribution. |
| `required_inbound_rules` | TCP 1514 + 1515 + UDP 514 open on the host SG. Aggregated by consumer-template. |
| `ansible` | `{role_path, playbook, host_group, vars}`. |
| `backup_plan` | Backrest plan contribution. |

## Notes

- SSL certs are generated once via the official `wazuh-certs-generator` one-shot container on first deploy, stored in `/opt/wazuh/config/wazuh_indexer_ssl_certs/`. Subsequent deploys reuse them. Set `wazuh_regenerate_certs: true` via `-e` on the next ansible run to throw them away and regen.
- Internal-user passwords (indexer admin, API, dashboard) are pinned (`ignore_changes = all` on the secret). Rotating them requires running `/var/ossec/api/scripts/wazuh-passwords-tool.sh` inside the manager.
- The manager API on port 55000 stays bound to `127.0.0.1` — agent traffic uses 1514/1515; UI hits the indexer + API via the dashboard's in-network connections.
- `vm.max_map_count` is set to 262144 via sysctl on the deploy host (OpenSearch refuses to start without it).
- Agent role (for hosts being monitored) ships in v2.7.1.
