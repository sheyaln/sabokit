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
chmod +x deploy.sh
./deploy.sh
```

After the first apply, run `terraform output compute_hosts` and drop the IPs into `inventory.ini`. Subsequent deploys: `./deploy.sh --skip-tags bootstrap` for fast app-only redeploys.

`deploy.sh` expects `sabokit/` to be reachable. Default is `../../../sabokit` (sibling of the consumer repo). Override with `FED_COMMONS_DIR=/path/to/sabokit ./deploy.sh`. The canonical pattern is a git submodule at the consumer repo root.
