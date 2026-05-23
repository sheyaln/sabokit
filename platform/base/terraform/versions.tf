terraform {
  required_version = ">= 1.5.0"

  required_providers {
    scaleway = {
      source  = "scaleway/scaleway"
      version = ">= 2.7.0"
      # The base module manages two kinds of Scaleway resources: most things
      # (compute, postgres, secrets, ...) in the deploy project, and the
      # gateway DNS record which often lives in a different project (some
      # orgs centralize DNS in a single "domains" project). Consumers pass a
      # `scaleway.dns` aliased provider — same creds as `scaleway` by default,
      # or separate ones for cross-project DNS.
      configuration_aliases = [scaleway.dns]
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.11"
    }
  }
}
