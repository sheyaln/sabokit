# local-validate

End-to-end `terraform validate` harness. Wires `platform/infra/terraform`, `platform/identity/terraform`, and `apps/outline` together to catch cross-module type mismatches in CI.

```bash
cd tests/local-validate
terraform init -backend=false
terraform validate
```

Not intended for `apply` — providers are configured with dummy credentials. Use this to verify a contract change doesn't break the platform↔app handshake.
