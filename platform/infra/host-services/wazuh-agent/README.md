# wazuh-agent

[Wazuh agent](https://documentation.wazuh.com/current/deployment-options/docker/wazuh-container.html) — host-network container that ships logs, FIM events, and system events to a Wazuh manager. Multi-instance: deploy once per host you want monitored.

Auto-enrolls via the `WAZUH_MANAGER_SERVER` env var. The agent's `hostname` becomes its registered name on the manager — keep stable; renaming creates a new agent record.

File Integrity Monitoring is **on by default**: a custom `ossec.conf` is mounted at `/wazuh-config-mount/etc/ossec.conf` (overriding the image's auto-config) with `syscheck` enabled, and host `auditd` rules are dropped at `/etc/audit/rules.d/wazuh.rules` so audit events flow through the agent's `localfile` reader on `/var/log/audit/audit.log`.

## Inputs

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `enabled` | `bool` | `false` | Master toggle. |
| `base` | object | — | Outputs from `module.base`. |
| `deployment_host_key` | `string` | — (required when enabled) | Which host this agent runs on. |
| `image` | `string` | `"wazuh/wazuh-agent"` | Image repo. |
| `release_version` | `string` | `"4.9.0"` | Image tag. MUST match the manager's `release_version`. |
| `agent_name` | `string` | `""` (falls back to `deployment_host_key`) | Stable name registered with the manager. |
| `manager_address` | `string` | — (required when enabled) | Manager's network address (private IP or DNS). |
| `diun_watch_enabled` | `bool` | `true` | Diun new-image notification opt-in. Agent must match manager version though, so bump lockstep when notified. |
| `autoheal_enabled` | `bool` | `true` | |
| `fim_enabled` | `bool` | `true` | FIM master toggle. Disable only if shipping FIM out-of-band. |
| `fim_extra_paths` | `list(string)` | `[]` | Extra absolute paths to monitor (added to auditd rules + syscheck). |
| `fim_extra_exclusions` | `list(string)` | `[]` | Paths to add as `<ignore>` entries in syscheck. |

## Outputs

| Name | Description |
|------|-------------|
| `enabled` | Mirrors `var.enabled`. |
| `ansible` | `{role_path, playbook, host_group, vars}`. |

## Notes

- Uses `network_mode: host` because the agent monitors host-level logs and connects to the manager over the host's network interfaces.
- Reads `/var/log` read-only — bind-mounted from the host. When `fim_enabled = true`, `/var/log/audit` is also bind-mounted so the agent can tail `audit.log`.
- Auto-instantiated per `var.compute_hosts` entry from `platform/infra/terraform/host_services.tf`. Consumer surface is the `wazuh_agent.{enabled, disabled_hosts, manager_address, ...}` block in `infra.yml` — see `platform/infra/terraform/variables.tf`. `manager_address` is the wazuh manager's private IP (surfaced by the operations layer's `wazuh.manager_private_ip` output); set it in `infra.yml`'s `wazuh_agent` block.
- FIM auditd rules require the `auditd` package on the host. The role skips rendering them (and emits a debug warning) when `/etc/audit/rules.d` is absent. Syscheck still runs in that case — only the kernel-sourced `-w … -p wa -k …` events are missed.
- `rootcheck`, `syscollector scan_on_start`, and `syscheck realtime="yes"` on large trees are intentionally avoided — historical sources of agent OOMs and manager crashes.

## What's monitored by default

Both auditd watchers (kernel-level write events) and syscheck (scheduled hash comparisons):

- **Identity / auth**: `/etc/passwd`, `/etc/shadow`, `/etc/group`, `/etc/gshadow`, `/etc/sudoers`, `/etc/sudoers.d/`, `/etc/pam.d/`
- **SSH**: `/etc/ssh/sshd_config`, `/etc/ssh/sshd_config.d/`, `/root/.ssh/` (realtime on `/etc/ssh`, `/etc/sudoers.d`, `/etc/pam.d`)
- **Cron**: `/etc/crontab`, `/etc/cron.d/`, `/etc/cron.{hourly,daily,weekly,monthly}/`, `/var/spool/cron/`
- **Network config**: `/etc/hosts`, `/etc/resolv.conf`
- **Service units**: `/etc/systemd/system/`, `/lib/systemd/system/`
- **Container runtime config**: `/etc/docker/daemon.json`
- **Binaries / boot** (syscheck only): `/usr/bin`, `/usr/sbin`, `/bin`, `/sbin`, `/boot`

Default exclusions (noisy files inside otherwise monitored dirs): `/etc/mtab`, `/etc/adjtime`, `/etc/random-seed`, `/etc/random.seed`, `/etc/utmpx`, `/etc/wtmpx`, `/etc/hosts.deny`, `/etc/mail/statistics`, `/etc/cups/certs`, `/etc/dumpdates`, `/etc/svc/volatile`, `/etc/httpd/logs`.
