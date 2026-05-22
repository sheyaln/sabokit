terraform {
  required_version = ">= 1.5.0"
  required_providers {
    scaleway = { source = "scaleway/scaleway", version = ">= 2.7.0" }
    random   = { source = "hashicorp/random", version = "~> 3.0" }
  }
}
