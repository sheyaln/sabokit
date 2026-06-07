# ansible-local/

Consumer-local Ansible roles + the wrapper `site.yml` that drives a deploy.

The wrapper imports upstream's `platform/ansible/site.yml` first (bootstrap + every shipped app bundle), then leaves room for consumer-local role imports — useful for apps that haven't been upstreamed yet or for org-specific roles that won't ever go upstream.

```
ansible-local/
├── site.yml          # wrapper — imports upstream first, then your local roles
├── roles/            # consumer-local roles (one dir per role)
└── group_vars/       # per-inventory-group var overrides (optional)
```

## Adding a local role

```bash
mkdir -p ansible-local/roles/my-thing/{tasks,defaults,templates,handlers,meta}
$EDITOR ansible-local/roles/my-thing/tasks/main.yml
# Add an `import_playbook` block to ansible-local/site.yml (see comment skeleton).
```

For roles that will eventually go upstream: structure them like a `platform/application/<name>/ansible/roles/<name>/` so the eventual port is a straight copy.

## When upstream ships a bundle that supersedes a local role

```bash
# 1. Enable the upstream bundle in environments/<env>/application.yml
# 2. scripts/application.sh <env>  (the new module starts creating cloud resources)
# 3. If you have existing state, terraform state mv local.<old> module.<new>
# 4. Delete ansible-local/roles/<old> and the import_playbook entry in site.yml
```
