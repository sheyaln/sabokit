# apps/privacy-policy

Public static HTML page for serving your organization's privacy policy at a stable URL. Single nginx container behind Traefik, DNS A record, no DB, no Authentik integration — privacy policies must be reachable without login for compliance. The consumer supplies HTML and (optionally) a logo via Ansible vars.

## Inputs

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `enabled` | `bool` | `false` | Master toggle. |
| `base` | object | — | Outputs from `module.base`. Only consumes `compute` + `domains` — Authentik is intentionally not consumed. |
| `hostname` | `string` | — (required when enabled) | Full hostname the page is served at. |
| `page_title` | `string` | `"Privacy Policy"` | Browser tab title (placeholder only; replaced when you supply your own HTML). |
| `monitoring_enabled` | `bool` | `true` | Wire access log paths into monitoring. |
| `deployment_host_key` | `string` | `"apps"` | Target host. |

## Ansible role variables

| Name | Default | Description |
|------|---------|-------------|
| `privacy-policy_html_path` | `""` | Path on the Ansible controller to the org's HTML. Empty → labelled placeholder. |
| `privacy-policy_logo_path` | `""` | Path on the Ansible controller to a logo (PNG/SVG). Empty → no logo mounted. |
| `privacy-policy_logo_filename` | `"logo.png"` | Basename the logo is served as inside the container. Override if your HTML references a specific filename. |
| `privacy-policy_image` | `"nginx:alpine"` | Container image. |

## Outputs

| Name | Description |
|------|-------------|
| `enabled` | Mirrors `var.enabled`. |
| `app_url` | `https://<hostname>`. |
| `monitoring` | Contribution map (log paths only). |
| `ansible` | `{role_path, playbook, host_group, vars}`. |
