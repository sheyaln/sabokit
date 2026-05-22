# environments/_template

Copy this dir to create a new environment:

```bash
cp -r environments/_template environments/prod
cp -r environments/_template environments/staging
```

Then per env:

```bash
cd environments/prod
cp terraform.tfvars.example terraform.tfvars      # fill in
cp backend.hcl.example      backend.hcl           # fill in (bucket+key)
cp inventory.ini.example    inventory.ini         # add hosts after first apply
chmod +x preflight.sh deploy.sh

./preflight.sh                                    # one-time per env
./deploy.sh
```

`preflight.sh` is idempotent — re-run it as often as you like. It checks the Scaleway credentials, installs the `scaleway` Python SDK into Ansible's interpreter, uploads your SSH key to the project keystore if it's missing, and creates a placeholder DNS A record for `gateway_domain` so Let's Encrypt can issue a cert when `deploy.sh` brings the gateway up. If your DNS zone lives in a different Scaleway project from this one, export `SCW_DNS_ACCESS_KEY` / `SCW_DNS_SECRET_KEY` before running.

`deploy.sh` is also idempotent — first run does cold-start, subsequent runs are a fast re-apply. Use `./deploy.sh --skip-tags bootstrap` to skip the Ansible bootstrap phase for app-only redeploys.

`deploy.sh` expects `sabokit/` to be reachable. Default is `../../../sabokit` (sibling of the consumer repo). Override with `FED_COMMONS_DIR=/path/to/sabokit ./deploy.sh`. The canonical pattern is a git submodule at the consumer repo root.
