# workflows/

Source-of-truth for n8n workflow JSON exports auto-imported on every deploy.

Drop `*.json` files exported from n8n's UI (`Workflows -> menu -> Download`) into
this directory. On each `ansible-playbook ../../../platform/ansible/application.yml ...`
run (from `environments/<env>/`) the n8n role syncs them to the apps host and runs
`n8n import:workflow --separate --input=/workflows-import/` inside the
container. n8n's importer upserts by workflow `id`, so re-runs are idempotent
and a workflow edited in the UI gets clobbered on the next deploy unless the
`id` is changed.

## Wiring

In your env's tfvars:

```hcl
apps = {
  n8n = {
    enabled       = true
    hostname      = "flows.example.org"
    workflows_dir = "../../workflows"   # relative to environments/<env>/
  }
}
```

Empty / unset = feature disabled, nothing is copied or imported.

## Conventions

- Workflows must have stable `id` fields (n8n preserves the id on export).
- Workflows ship as `active: false`. Activate manually after first import or
  flip via the UI; re-importing will not change the active state from your
  source JSON unless you pass `--activeState=fromJson` (not wired here; would
  reactivate paused workflows on every deploy).
- Credentials are NOT in the JSON. Re-bind credentials in the n8n UI once after
  first import; the bindings live in the database and survive subsequent
  imports.
- Whatever you commit here gets deployed. Treat this as production source.
