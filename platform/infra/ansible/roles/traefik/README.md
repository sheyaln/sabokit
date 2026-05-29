# traefik

Deploys Traefik v3 as a Docker-Compose service. Includes:

- Let's Encrypt cert issuance via HTTP-01 challenge.
- A locked-down docker-socket-proxy (read-only enumeration, no exec).
- File-provider middlewares: `security-headers@file`, `rate-limit@file`, and `authentik-auth@file` when an outpost URL is configured.
- Prometheus metrics on `traefik_metrics_port`.
- Optional Fail2ban filters and jail config — installed only if Fail2ban is present.

App stacks join Traefik by attaching to the `traefik` Docker network (configurable) and using Traefik labels to declare their routes.

## Required variables

| Variable | Purpose |
|----------|---------|
| `traefik_acme_email` | Contact email for Let's Encrypt. The role asserts on this. |

## Recommended variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `traefik_authentik_outpost_url` | `""` | URL Traefik calls to gate apps behind Authentik SSO. Without this, the `authentik-auth@file` middleware is **not rendered** and any app referencing it will 503. Set per host. |

Two valid shapes:

- Authentik host itself: `http://authentik-server:9000/outpost.goauthentik.io/auth/traefik`
- Any other host: `https://auth.example.org/outpost.goauthentik.io/auth/traefik`

## Other useful variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `traefik_dir` | `/opt/traefik` | Install / data directory on host. |
| `traefik_owner` | `ubuntu` | User that owns the compose project files. |
| `traefik_docker_network` | `traefik` | External Docker network apps attach to. |
| `traefik_image` | `traefik:v3.1` | Image tag pin. |
| `traefik_metrics_port` | `9101` | Prometheus metrics port. |
| `traefik_metrics_bind_address` | `""` | IP to bind metrics port to. Empty = all interfaces. |
| `traefik_trust_forwarded_headers` | `false` | Set true ONLY on the Authentik host when other Traefiks forward auth checks to it. |
| `traefik_default_tls_options` | `""` | Default TLS option for the websecure entrypoint. Empty = each router picks via labels. |
| `traefik_csp_extra_script_src` | `[]` | Append to the CSP `script-src` directive. |
| `traefik_csp_extra_font_src` | `[]` | Append to the CSP `font-src` directive. |
| `traefik_csp_extra_connect_src` | `[]` | Append to the CSP `connect-src` directive. |
| `traefik_external_redirects` | `[]` | Host -> URL 301 redirects rendered into dynamic.yml. Each item: `{ name, host, target }`. |

## Dependencies

- `docker` role (declared in `meta/main.yml`).
- `fail2ban` role (optional; filters are only installed if Fail2ban is present).
- `community.docker` Ansible collection.

## Usage

```yaml
- hosts: apps
  become: true
  roles:
    - role: docker
    - role: fail2ban
    - role: traefik
      vars:
        traefik_acme_email: "ops@example.org"
        traefik_authentik_outpost_url: "https://auth.example.org/outpost.goauthentik.io/auth/traefik"
```

## Wiring an app's compose service to Traefik

```yaml
services:
  myapp:
    image: ghcr.io/example/myapp:latest
    networks: [traefik]
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.myapp.rule=Host(`myapp.example.org`)"
      - "traefik.http.routers.myapp.entrypoints=websecure"
      - "traefik.http.routers.myapp.tls.certresolver=le"
      - "traefik.http.routers.myapp.middlewares=security-headers@file,authentik-auth@file"
      - "traefik.http.services.myapp.loadbalancer.server.port=3000"
networks:
  traefik:
    external: true
```
