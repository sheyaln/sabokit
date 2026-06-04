# operations/protonmail-bridge

IMAP gateway for apps that need to FETCH mail from a ProtonMail account (typically n8n workflows polling an inbox). A shared mail-provider service in the operations tier; composes in `platform/operations/terraform/`, gated on `var.protonmail_bridge`.

**Not for SMTP.** Outbound mail is handled by Scaleway TEM in the `platform/infra/` tier — infra writes the well-known `smtp-config` Scaleway secret that every app sends through. This bundle writes the parallel `imap-config` secret apps consume when they need to receive.

## Mail-provider convention: one provider per capability, no abstract dispatcher

Each mail/IMAP provider gets its own bundle; a consumer picks **one** for a given capability by enabling exactly that provider. There is no abstract `smtp-gateway`/`imap-gateway` module that dispatches across providers. Why:

- Provider semantics differ wildly — ProtonMail Bridge needs interactive first-login + a runtime IMAP container; Scaleway TEM is an API-key relay with no container; generic SMTP is just credentials. An abstract dispatcher would leak every provider's quirks into one variable surface.
- Picking a provider is a one-shot wiring decision, not a runtime switch.
- Each provider bundle stays single-purpose and reads cleanly.

Apps never care which provider produced the secret — they read `imap-config` (inbound) / `smtp-config` (outbound) by name. Planned siblings, not yet built: a TEM SMTP-relay container (the API-direct path already covers most apps) and a generic BYO-SMTP relay (Mailgun/SES/Postfix) writing `smtp-config`, mutually exclusive with the TEM path.

## Inputs

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `enabled` | `bool` | `false` | Master toggle. |
| `base` | object | — | Outputs from `module.base`. |
| `deployment_host_key` | `string` | `"management"` | Host the bridge runs on. Reachable from every host with mail-fetching apps. |
| `image` | `string` | `"shenxn/protonmail-bridge"` | Community-maintained prebuilt; ProtonMail doesn't publish an official image. |
| `image_tag` | `string` | `"latest"` | |
| `imap_username` | `string` | — (required) | ProtonMail account email used for bridge login. Apps use this as their IMAP username. |
| `bridge_login_secret_id` | `string` | — (required) | Scaleway secret ID holding the bridge's SERVICE-SPECIFIC password. Consumer-managed (see "First-time setup"). |
| `imap_config_secret_name` | `string` | `"imap-config"` | Name of the secret this bundle writes. Override only for multi-bridge setups. |
| `memory_limit` / `memory_reservation` | `string` | `"256M"` / `"64M"` | |
| `cpu_limit` / `cpu_reservation` | `string` | `"0.5"` / `"0.05"` | |
| `timezone` | `string` | `"UTC"` | |
| `diun_watch_enabled` | `bool` | `false` | Off by default — bridge schema migrations between minor versions need re-login, so notification noise isn't actionable. |
| `autoheal_enabled` | `bool` | `true` | |
| `backup_enabled` | `bool` | `true` | Backs up the bridge data volume (contains login state). |
| `backup_extra_paths` / `backup_schedule_cron` / `backup_retention` | (see vars) | — | |

## Outputs

| Name | Description |
|------|-------------|
| `enabled` | Mirrors `var.enabled`. |
| `imap_config_secret_id` | ID of the Scaleway secret apps consume for IMAP credentials. |
| `imap_endpoint` | `{host, port, use_tls}` for diagnostics. |
| `ansible` | `{role_path, playbook, host_group, vars}`. |
| `backup_plan` | Backrest plan contribution. |

## First-time setup

The bridge requires an interactive login on first deploy. ProtonMail doesn't support headless credential injection.

1. **In ProtonMail web UI**: Settings → ProtonMail Bridge → generate a bridge password. Note it.
2. **Create Scaleway secret** for the bridge password:
   ```bash
   scw secret create name=protonmail-bridge-login type=text
   scw secret version create secret-id=<id> data="<bridge-password>"
   ```
   Pass the secret ID into `bridge_login_secret_id`.
3. **First `terraform apply` + `ansible-playbook`** brings the container up.
4. **Log in once via container CLI**:
   ```bash
   ssh management
   docker exec -it protonmail-bridge bridge --cli
   bridge> login
   # ProtonMail email + the bridge password from step 1
   bridge> exit
   ```
5. Subsequent deploys reuse the persisted login state.

## Apps that fetch mail

Reference the secret by name in your app's Ansible vars (or n8n credentials):
- Host: `protonmail-bridge`
- Port: `143`
- TLS: STARTTLS
- Username: the ProtonMail email
- Password: from the `imap-config` Scaleway secret

n8n workflow IMAP nodes: create an IMAP credential pointing at this; reference in the workflow's Trigger node.

## Notes

- Container listens on docker hostname `protonmail-bridge:143`. Apps must join `protonmail-bridge-net` docker network OR bridge must be joined to the app's network.
- Data volume contains login state — backed up by default via `backup_plan`.
- Outbound mail (SMTP) is NOT handled here. Use Scaleway TEM (infra tier).
