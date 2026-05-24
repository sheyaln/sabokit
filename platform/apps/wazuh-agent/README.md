# apps/wazuh-agent

[Wazuh agent](https://documentation.wazuh.com/current/deployment-options/docker/wazuh-container.html) — host-network container that ships logs + system events to a Wazuh manager. Multi-instance: deploy once per host you want monitored.

Auto-enrolls via the `WAZUH_MANAGER_SERVER` env var. The agent's `hostname` becomes its registered name on the manager — keep stable; renaming creates a new agent record.

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
| `auto_update_enabled` | `bool` | `false` | Off by default — agent version must match manager; bump lockstep. |
| `autoheal_enabled` | `bool` | `true` | |

## Outputs

| Name | Description |
|------|-------------|
| `enabled` | Mirrors `var.enabled`. |
| `ansible` | `{role_path, playbook, host_group, vars}`. |

## Notes

- Uses `network_mode: host` because the agent monitors host-level logs and connects to the manager over the host's network interfaces.
- Reads `/var/log` read-only — bind-mounted from the host.
- For multiple monitored hosts: instantiate this module once per host. The example pattern in consumer-template uses keys like `wazuh_agent_apps`, `wazuh_agent_management`, etc.
