terraform {
  required_version = ">= 1.7.0"

  required_providers {
    # Default (unaliased) providers, inherited from the calling layer root.
    # No scaleway.dns alias: this module reads existing resources, it never
    # touches DNS — which is also why it validates standalone (no
    # configuration_aliases to satisfy with a wrapper).
    scaleway = {
      source  = "scaleway/scaleway"
      version = ">= 2.7.0"
    }
    # Permissive on purpose — this shared module just reads groups/flows, which
    # are stable across releases. The consumer root pins the actual provider
    # version (and the authentik_version knob pins the server). A tight `~>`
    # here would cap the whole layer below the consumer's pin (e.g. the 2026.x
    # upgrade path), so match the layer modules' range instead.
    authentik = {
      source  = "goauthentik/authentik"
      version = ">= 2024.6.0, < 2027.0.0"
    }
  }
}
