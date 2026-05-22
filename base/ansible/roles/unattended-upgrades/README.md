# unattended-upgrades

Enables automatic security upgrades via Debian's `unattended-upgrades` package. Optional email and webhook notifications.

## Variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `unattended_upgrades_email_enabled` | `false` | Send result emails. Needs working MTA. |
| `unattended_upgrades_mail_to` | `""` | **REQUIRED** when email enabled. Destination. |
| `unattended_upgrades_mail_from` | `unattended-upgrades@localhost` | Sender. |
| `unattended_upgrades_mail_report` | `on-change` | `always` \| `only-on-error` \| `on-change`. |
| `unattended_upgrades_postfix_domain` | `""` | Optional. Sets postfix myhostname/mydomain if non-empty. |
| `unattended_upgrades_automatic_reboot` | `false` | Auto-reboot when kernel update requires it. |
| `unattended_upgrades_automatic_reboot_time` | `02:00` | Reboot window. |
| `unattended_upgrades_webhook_enabled` | `false` | Fire HTTPS webhook after each run. |
| `unattended_upgrades_webhook_url` | `""` | **REQUIRED** when webhook enabled. |
| `unattended_upgrades_origins` | Ubuntu security + updates | Apt origins to auto-upgrade from. |
| `unattended_upgrades_package_blacklist` | `[]` | Python regex patterns to skip. |

## Dependencies

None.

## Usage

```yaml
- hosts: all
  become: true
  roles:
    - role: unattended-upgrades
      vars:
        unattended_upgrades_automatic_reboot: true
        unattended_upgrades_automatic_reboot_time: "03:30"
```
