# scw-secrets

The secrets-fetching abstraction every app bundle depends on. Installs the Scaleway CLI under a dedicated service account, plus two helper scripts:

- `fetch-secrets <app> <out-dir>` — reads a per-app mapping file and writes each referenced Scaleway secret as a file into `<out-dir>`.
- `entrypoint-with-secrets <app> [cmd...]` — container entrypoint wrapper that fetches secrets into `/run/secrets` (tmpfs) then `exec`s the real command.

App roles register their secret needs by including `tasks_from: deploy-mapping` and passing `scw_secrets_app_name` + `scw_secrets_mapping`.

## Required variables

| Variable | Purpose |
|----------|---------|
| `scw_secrets_access_key` | Scaleway API access key. Should be scoped to `SecretManagerReadOnly`. Reads `SCW_SECRETS_ACCESS_KEY` or `scaleway_access_key` by default. |
| `scw_secrets_secret_key` | Scaleway API secret key. Same env-var fallback chain. |
| `scw_secrets_project_id` | Scaleway project ID. Reads `SCW_DEFAULT_PROJECT_ID` env var by default. |

The smoke-test task is skipped if `scw_secrets_project_id` is empty, so the role can still install on hosts you intend to wire credentials onto later.

## Optional variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `scw_cli_version` | `latest` | Pin a specific Scaleway CLI version. |
| `scw_secrets_organization_id` | env or `""` | Scaleway organization ID. |
| `scw_secrets_region` | `fr-par` | Default Secret Manager region. |
| `scw_secrets_user` / `scw_secrets_group` | `scw-secrets` | Service account name. |
| `scw_secrets_uid` / `scw_secrets_gid` | `990` | Service account UID/GID. |
| `scw_secrets_base_dir` | `/opt/scw-secrets` | Install root. |
| `scw_secrets_allow_docker_group` | `true` | Grant the `docker` group sudo access to fetch-secrets. |
| `scw_secrets_sudo_user` | unset | Optional extra user granted sudo access for manual debugging. |
| `scw_secrets_log_level` | `info` | `debug` \| `info` \| `warn` \| `error`. |
| `scw_secrets_log_file` | `/var/log/scw-secrets/fetch.log` | Empty string disables file logging. |

## Dependencies

None at the Ansible level, but the helper scripts assume `sudo`, `bash`, `curl`, `base64` are available — they are in every supported base image.

## Usage

Install the toolchain on a host:

```yaml
- hosts: all
  become: true
  roles:
    - role: scw-secrets
      vars:
        scw_secrets_project_id: "11111111-2222-3333-4444-555555555555"
```

Inside an app role, declare which secrets the app needs:

```yaml
- name: Register Outline secrets
  ansible.builtin.include_role:
    name: scw-secrets
    tasks_from: deploy-mapping
  vars:
    scw_secrets_app_name: outline
    scw_secrets_mapping:
      db_password:        postgres-outline/password
      secret_key:         outline-secret-key
      oidc_client_secret: outline-oidc/client_secret
```

Then in the app's `docker-compose.yml`:

```yaml
services:
  outline:
    entrypoint: ["/opt/scw-secrets/bin/entrypoint-with-secrets", "outline"]
    command:    ["yarn", "start"]
    environment:
      DATABASE_URL_FILE: /run/secrets/db_password   # app reads from tmpfs
    tmpfs:
      - /run/secrets:mode=0700
```

## Mapping file format

The mapping file written under `/opt/scw-secrets/mappings/<app>.yml` looks like:

```yaml
secrets:
  db_password:        postgres-outline/password
  secret_key:         outline-secret-key
  oidc_client_secret: outline-oidc/client_secret
```

Each value is `<scaleway-secret-name>` or `<scaleway-secret-name>/<json-key>` for `key_value` secrets.
