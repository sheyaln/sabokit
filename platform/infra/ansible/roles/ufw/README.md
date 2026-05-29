# ufw

Installs and enables UFW with a deny-by-default inbound policy. Opens SSH (22), HTTP (80), and HTTPS (443) by default. Everything else is consumer-driven via `ufw_extra_rules`.

## Variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `ssh_port` | `22` | SSH port to open. Set this before locking yourself out. |
| `ufw_allow_http` | `true` | Open port 80. |
| `ufw_allow_https` | `true` | Open port 443. |
| `ufw_default_incoming` | `deny` | Default inbound policy. |
| `ufw_default_outgoing` | `allow` | Default outbound policy. |
| `ufw_default_routed` | `deny` | Default routed policy. |
| `ufw_reset_on_apply` | `false` | `ufw reset` before applying. Useful only on first bootstrap. |
| `ufw_logging_level` | `low` | `off` \| `low` \| `medium` \| `high` \| `full`. |
| `ufw_extra_rules` | `[]` | List of dicts passed to `community.general.ufw`. |

## Dependencies

Requires the `community.general` collection.

## Usage

Bare minimum:

```yaml
- hosts: all
  become: true
  roles:
    - role: ufw
```

With extra rules — e.g. exposing node_exporter to a private monitoring subnet:

```yaml
- hosts: all
  become: true
  roles:
    - role: ufw
      vars:
        ufw_extra_rules:
          - { rule: allow, port: "9100", proto: tcp, from_ip: "10.0.0.0/16", comment: "node_exporter" }
          - { rule: allow, port: "8080", proto: tcp, from_ip: "10.0.0.0/16", comment: "cadvisor" }
```
