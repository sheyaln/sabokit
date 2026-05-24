# split-dns

dnsmasq on every host, overriding the public app hostnames with private VPC IPs so cross-host hostname references route over the private network instead of the public internet.

Required when the deployment spans more than one VM AND any app references another app by its public hostname (the common case: Grafana on the management host pointing at `loki.example.org` which lives on the apps host).

## Variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `split_dns_overrides` | `{}` | Map of `"hostname" -> "private-ip"`. Built by the consumer-template from each enabled bundle's `ansible.split_dns_entry`. Empty = role no-ops (single-host deployments). |
| `split_dns_upstream_servers` | `[169.254.169.254, 1.1.1.1]` | Where dnsmasq forwards anything not in the overrides map. Scaleway metadata DNS first, then Cloudflare. |
| `split_dns_docker_bridge_ip` | `172.17.0.1` | dnsmasq binds this so docker containers can resolve. Change only if Docker's `bip` is non-default. |
| `split_dns_allowed_cidr` | `172.16.0.0/12` | UFW allow source for :53. Covers Docker bridges + Scaleway VPC under 172.16/12. Override for 10.0/8 VPCs. |
| `split_dns_config_path` | `/etc/dnsmasq.d/fc-split.conf` | Drop-in path. Distinct filename so `cat`ing it shows only fc-managed overrides. |

## Behaviour worth knowing

- **No-op when overrides is empty.** The first task ends the play. Single-host deployments never install dnsmasq.
- **Evicts systemd-resolved.** Ubuntu's default :53 squatter is stopped + disabled; `/etc/resolv.conf` is replaced. The role takes a temporary detour through an upstream resolver so apt can still resolve while dnsmasq is being installed.
- **Runs before docker.** `bind-dynamic` handles `docker0` not existing yet — dnsmasq binds when the interface appears.
- **Requires `ufw` role to have run first.** The role adds allow rules but doesn't enable UFW.

## Usage

The consumer-template wires this automatically — `platform/ansible/bootstrap.yml` runs the role on every host with `split_dns_overrides` extra-var supplied from `terraform output`. Direct use:

```yaml
- hosts: all
  become: true
  roles:
    - role: ufw
    - role: split-dns
      vars:
        split_dns_overrides:
          loki.example.org: 10.0.1.5
          prometheus.example.org: 10.0.1.5
```
