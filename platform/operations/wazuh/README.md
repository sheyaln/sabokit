# apps/wazuh

[Wazuh](https://wazuh.com) server stack — manager + indexer (OpenSearch fork) + dashboard. SIEM + endpoint detection. Dashboard delegates SSO to opensearch-security's native OIDC backend pointed at Authentik — users hit the dashboard with their own identity, group claims become opensearch backend roles via `roles_mapping.yml`.

Agent role for monitored hosts ships separately. The bundle opens the manager's agent/enrollment/syslog ports in the host SG via `required_inbound_rules`.

## Inputs

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `enabled` | `bool` | `false` | Master toggle. |
| `base` | object | — | Outputs from `module.base`. |
| `hostname` | `string` | — (required when enabled) | Dashboard hostname. |
| `category_group` | `string` | `"Security"` | Authentik portal category. |
| `icon_url` | `string` | `null` | Optional icon. |
| `authorized_groups` | `list(string)` | `["admin"]` | Authentik group names allowed in. Higher tiers nest under lower, so naming a baseline tier admits every tier above it. Defaults admin-only — SIEM + active response. |
| `oidc_admin_group` | `string` | `"admin"` | Authentik group mapped to opensearch `all_access` (full dashboard + active response). |
| `oidc_readonly_group` | `string` | `""` | Optional Authentik group mapped to `kibana_user` + `readall` (read-only dashboard). Empty = admin-only. |
| `monitoring_enabled` | `bool` | `true` | Wire log paths into monitoring. |
| `deployment_host_key` | `string` | `"management"` | Host this manager runs on. |
| `version` | `string` | `"4.9.0"` | Wazuh release. All 3 images move in lockstep. |
| `indexer_heap_size` | `string` | `"1g"` | OpenSearch JVM heap (50% of host RAM, max 31g). |
| `manager_agent_port` | `number` | `1514` | TCP port for agent connections. |
| `manager_enrollment_port` | `number` | `1515` | TCP port for agent enrollment. |
| `manager_syslog_port` | `number` | `514` | UDP port for syslog ingestion. |
| `memory_limit` / `memory_reservation` | `string` | `"2G"` / `"512M"` | Manager container memory. |
| `cpu_limit` / `cpu_reservation` | `string` | `"2.0"` / `"0.5"` | Manager container CPU. |
| `diun_watch_enabled` | `bool` | `true` | Diun new-image notification opt-in. Bump the 3 images lockstep when notified. |
| `autoheal_enabled` | `bool` | `true` | |
| `backup_enabled` | `bool` | `true` | Indexer data + manager state backed up by default. |
| `backup_extra_paths` / `backup_schedule_cron` / `backup_retention` | (see vars) | — | |

## Outputs

| Name | Description |
|------|-------------|
| `enabled` | Mirrors `var.enabled`. |
| `app_url` | `https://<hostname>` or null. |
| `authentik_provider_id` | OIDC provider ID. Wazuh uses **native** OIDC via opensearch-security, not the embedded forward-auth outpost — its provider is never bound into the application layer's outpost. Exposed for tooling. |
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
- opensearch-security config (`config.yml`, `roles_mapping.yml`, `internal_users.yml`) is mutated live via `securityadmin.sh` against the running indexer — restarting containers alone won't pick up changes once the security index has been initialised.
- Dashboard login: `opensearch_security.auth.type` is `["basicauth", "openid"]`. The login page presents both; pick "Log in with single sign-on" for Authentik. Direct-to-OIDC redirect is a future v3 knob.
