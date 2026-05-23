# secrets

Provisions Scaleway Secret Manager containers from a category-keyed config map. Each secret declares whether the module should auto-generate a value (`generate = true`), accept a literal value from config (`value = "..."`), or expect a manual upload after the apply (neither).

Templated value substitution is supported for a small set of placeholders (`{{ domains.management }}`, `{{ domains.tools }}`) pulled from the optional `project_config` input. The `manual_secrets_needed` output lists every container created without a value so operators know what they must upload by hand.

## Usage

```hcl
module "secrets" {
  source = "git::https://github.com/sheyaln/sabokit.git//modules/infrastructure/secrets?ref=v2.3.0"

  secrets        = yamldecode(file("config/secrets.yml")).secrets
  project_config = yamldecode(file("config/project.yml"))
}
```

## Inputs

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `secrets` | `map(list(object({ name, description, type, path?, generate?, length?, value?, tags? })))` | `{}` | Map of secret categories to secret configurations. |
| `project_config` | `any` | `{}` | Project configuration from `config/project.yml` for templating secret values. |

## Outputs

| Name | Description |
|------|-------------|
| `secret_ids` | Map of secret names to their Scaleway secret IDs. |
| `secret_paths` | Map of secret names to their paths (for Ansible lookups). |
| `secrets` | Full secret resources for reference. |
| `manual_secrets_needed` | List of secrets that need manual upload to Scaleway (not auto-generated, no predefined value). |
| `valued_secrets` | List of secrets with predefined values from config. |
