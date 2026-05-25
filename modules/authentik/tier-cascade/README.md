# tier-cascade

Chained Authentik groups where each tier inherits all tiers below it.

## Inputs

| Name | Type | Default | Notes |
|------|------|---------|-------|
| `tier_names` | `list(string)` | `["member", "delegate", "treasurer", "admin"]` | Display names — become the actual Authentik group names. Lowest privilege first. |
| `tier_keys` | `list(string)` | `null` (= `tier_names`) | Logical identifiers parallel to `tier_names`. Bundles' `var.tier_access_level` references these. Set when you override `tier_names` to brand display names. |
| `admin_tier` | `string` | last entry of `tier_names` | Tier flagged `is_superuser = true`. |
| `admin_user_pks` | `list(number)` | `null` | Optional explicit admin members. `null` = UI-managed. |
| `tier_attributes` | `map(string)` | `{}` | Per-tier description override. |

## Outputs

| Name | Shape | Use |
|------|-------|-----|
| `groups` | `map(name → group_id)` | Merge into `base.authentik.groups`. |
| `tier_cascade` | `map(key → map(name → group_id))` | Outer keys are `tier_keys` (logical, stable across rebranding). `tier_cascade[T]` = every tier at-or-above `T`. Drop into app bundles' `authorized_groups`. |
| `admin_tier` | `string` | Echo of the resolved admin tier name. |

## How it works

Authentik group nesting: a child group's members are effective members of the parent for application-policy decisions. The module chains `tier[i].parents = [tier[i-1]]` so the highest-privilege tier sits at the bottom of the chain and cascades up.

The provider's `parents` is `list(string)` but Authentik stores a single parent FK upstream — we always pass a one-element list.

## When NOT to use this

App needs unusual gating (e.g. one group of N service accounts, no inheritance). Use the bundle's `tier_cascade_enabled = false` opt-out and supply `access_level` + `extra_authorized_groups` directly.
