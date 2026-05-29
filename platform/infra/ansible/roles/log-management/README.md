# log-management

Caps systemd-journald disk usage and installs a baseline logrotate policy for system logs. Prevents small-disk VMs from filling up with months of journal data.

## Variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `journald_system_max_use` | `500M` | Total persistent journal size cap. |
| `journald_system_keep_free` | `1G` | Free disk to keep available. |
| `journald_system_max_file_size` | `50M` | Per-file journal size cap. |
| `journald_runtime_max_use` | `100M` | Runtime (in-memory) journal cap. |
| `journald_max_retention_sec` | `2weeks` | Max age of journal records. |
| `journald_compress` | `true` | Compress journal files. |
| `logrotate_ensure_timer_enabled` | `true` | Enable systemd `logrotate.timer`. |
| `log_management_vacuum_on_apply` | `true` | Vacuum oversized journals on first apply. |

## Dependencies

None.

## Usage

```yaml
- hosts: all
  become: true
  roles:
    - role: log-management
```
