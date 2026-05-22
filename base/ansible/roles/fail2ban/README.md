# fail2ban

Installs Fail2ban. App-specific filters and jails are dropped in by other roles (notably `traefik`, which ships filters under `/etc/fail2ban/filter.d/` and jails under `/etc/fail2ban/jail.d/`). Run this role before any role that ships jail configs.

## Variables

None. Defaults intentionally minimal — distribution package defaults plus the configs other roles install.

## Dependencies

None.

## Usage

```yaml
- hosts: all
  become: true
  roles:
    - role: fail2ban
    - role: traefik   # ships traefik-* jails
```
