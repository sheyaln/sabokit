# local-validate

End-to-end `terraform validate` harness. Wires `base/scaleway`, `base/authentik`, and `apps/outline` together to catch cross-module type mismatches in CI.

```bash
cd examples/local-validate
terraform init -backend=false
terraform validate
```

Not intended for `apply` — providers are configured with dummy credentials. Use this to verify a contract change doesn't break the platform↔app handshake.
