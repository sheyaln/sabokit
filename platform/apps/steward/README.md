# Steward (member administration UI)

Federated-commons bundle that deploys [Steward](https://github.com/dciww/steward), a
simplified Authentik admin UI for non-technical organization administrators.
It is the friendly admin surface for membership secretaries, organizers, and
chapter admins -- the people you don't want clicking around in the raw
Authentik admin UI.

## What this bundle provisions

| Layer | Resource | Notes |
| --- | --- | --- |
| Authentik | OIDC application + provider | end-user login (`/oidc/callback/`) |
| Authentik | service-account user + non-expiring API token | server-to-server admin API |
| Scaleway | PostgreSQL database via the `postgres_database` module | Steward's local schema (audit log, import jobs) |
| Scaleway Secret Manager | one app-secrets bag + DB-credentials secret | rendered into `.env` by Ansible |
| DNS | `A` record on `var.hostname` | points at the deployment host |
| Host (Ansible) | docker-compose stack: `web` + `qcluster` | served behind Traefik |

Steward holds **no local user mirror**. Authentik remains the source of truth
for member state; Steward only stores its own audit log and bulk-import job
state in its database.

## Wiring it into a consumer site

Steward is opt-in. Enable it in your apps Terraform layer (see
`consumer-template/`):

```hcl
module "steward" {
  source   = "../../platform/apps/steward/terraform"
  enabled  = true
  base     = module.base
  hostname = "members.example.org"
}
```

The bundle uses the standard contract: `enabled`, `base`, `hostname`,
`deployment_host_key`, `access_level`. See `terraform/variables.tf` for the
full list.

## Required base outputs

The bundle consumes the standard `module.base` outputs. Specifically:

- `base.authentik.gateway_domain` -- public Authentik hostname
- `base.authentik.groups[var.access_level]` -- group UUID gating access
- `base.authentik.flows.{authentication,authorization,invalidation}_flow` -- flow UUIDs
- `base.scaleway.postgres_instance_id` / `postgres_endpoint` / `postgres_engine`
- `base.compute.hosts[var.deployment_host_key].public_ip` / `ansible_group`
- `base.domains.base_domain`

## Admin gating

Members of the group named by `var.admin_group_name` (default
`steward-admins`) are admitted to Steward. The OIDC `groups` claim must
contain that group name -- the bundle requests the `groups` scope and Steward
verifies it on every login. Membership is managed in Authentik like any other
group.

## Service-account authority

`authentik.tf` puts the service-account user into the built-in
`authentik Admins` group, which grants blanket Authentik admin permissions.
That is more authority than Steward strictly needs (it only manipulates users
and groups). A future iteration should narrow this to a custom Authentik role.

## Invitation flow

`var.invite_flow_slug` is empty by default. Set it to the slug of an Authentik
enrollment flow you want Steward to attach to new-member invitations -- e.g.
`default-source-enrollment` if you've enabled the bundled enrollment flow.
Authentik handles email delivery; Steward never speaks SMTP itself.

## Operating it

Restart: `ansible -m community.docker.docker_compose_v2 -a "project_src=/opt/steward state=restarted" <host>`

Migrations: run automatically on every container start via Steward's
entrypoint. The qcluster sidecar opts out (one migrator is enough).

Logs: `docker logs steward-web` and `docker logs steward-qcluster`.

Reaching the admin Django site for emergencies: `docker exec -it steward-web
python manage.py createsuperuser`, then visit `https://<hostname>/admin/`.
The OIDC flow is the normal entry point; the Django admin is a break-glass
escape hatch.
