# docker

Installs Docker Engine and the Compose plugin from Docker's official apt repository, and applies safe container-log defaults.

## Variables

All optional.

| Variable | Default | Purpose |
|----------|---------|---------|
| `docker_log_driver` | `json-file` | Default logging driver for containers. |
| `docker_log_max_size` | `100m` | Per-container log rotation size. |
| `docker_log_max_file` | `3` | Number of rotated log files retained per container. |
| `docker_user` | `ubuntu` | User added to the `docker` group. Set to `""` to skip. |
| `docker_dns_servers` | unset | Optional list of resolver IPs Docker passes to containers. |

## Dependencies

None.

## Usage

```yaml
- hosts: all
  become: true
  roles:
    - role: docker
```
