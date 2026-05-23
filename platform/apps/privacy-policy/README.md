# apps/privacy-policy

Public static HTML page for serving your organization's privacy policy at a stable URL. nginx in a container, no DB, no auth. Self-contained bundle:

- DNS A record on the consumer's base domain
- Ansible role that deploys nginx behind Traefik
- Consumer provides the HTML content and (optionally) a logo

No Authentik integration — privacy policies must be reachable without login for compliance reasons. The bundle deliberately doesn't wire forward-auth.

## Usage

```hcl
module "privacy-policy" {
  source   = "git::https://github.com/sheyaln/sabokit.git//platform/apps/privacy-policy/terraform?ref=v2.2.0"
  enabled  = try(var.apps.privacy-policy.enabled, false)
  hostname = try(var.apps.privacy-policy.hostname, "")
  base     = module.base
}
```

In `terraform.tfvars`:

```hcl
apps = {
  privacy-policy = {
    enabled  = true
    hostname = "privacy.example.org"
  }
}
```

In `site.yml` — point at your org's HTML + logo files:

```yaml
- import_playbook: ../apps/privacy-policy/ansible/playbook.yml
  vars:
    privacy-policy_html_path: "{{ playbook_dir }}/files/privacy-policy.html"
    privacy-policy_logo_path: "{{ playbook_dir }}/files/org-logo.png"
```

Both file paths are optional. If `privacy-policy_html_path` is empty, the bundle ships a labelled placeholder so the deploy doesn't fail with an empty page. If `privacy-policy_logo_path` is empty, no logo is mounted or rendered.

## Inputs

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `enabled` | `bool` | `false` | Master toggle. |
| `base` | object | — | Outputs from `module.base`. Only consumes `compute` + `domains` — Authentik is intentionally not consumed. |
| `hostname` | `string` | — (required when enabled) | Full hostname the page is served at. |
| `page_title` | `string` | `"Privacy Policy"` | Browser tab title (used only by the placeholder; replaced when you supply your own HTML). |
| `monitoring_enabled` | `bool` | `true` | Wire access log paths into monitoring. |
| `deployment_host_key` | `string` | `"apps"` | Target host. |

## Ansible role variables

| Name | Default | Description |
|------|---------|-------------|
| `privacy-policy_html_path` | `""` | Path on the Ansible controller to the org's HTML. Empty → placeholder. |
| `privacy-policy_logo_path` | `""` | Path on the Ansible controller to a logo (PNG/SVG). Empty → no logo rendered. |
| `privacy-policy_logo_filename` | `"logo.png"` | Basename the logo is served as inside the container. Override if your HTML references a specific filename. |
| `privacy-policy_image` | `"nginx:alpine"` | Container image. |
| `privacy-policy_memory_limit` / `_cpu_limit` etc. | conservative | Resource caps. |

## Outputs

| Name | Description |
|------|-------------|
| `enabled` | Mirrors `var.enabled`. |
| `app_url` | `https://<hostname>`. |
| `monitoring` | Contribution map (log paths only). |
| `ansible` | `{role_path, playbook, host_group, vars}`. |

## Disabling

`apps.privacy-policy.enabled = false` + `terraform apply` drops the DNS record. The container survives on the host until you `docker compose down`.
