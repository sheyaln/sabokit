terraform {
  required_version = ">= 1.5.0"

  required_providers {
    scaleway = {
      source  = "scaleway/scaleway"
      version = ">= 2.7.0"
    }
    authentik = {
      source  = "goauthentik/authentik"
      version = ">= 2024.6.0, < 2027.0.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.11"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }

  # Replace with your remote state backend before running `terraform init`.
  # The example below uses Scaleway Object Storage (S3-compatible). Provision
  # the bucket out-of-band before init.
  #
  # backend "s3" {
  #   bucket                      = "<my-tfstate-bucket>"
  #   key                         = "consumer/terraform.tfstate"
  #   region                      = "fr-par"
  #   endpoints                   = { s3 = "https://s3.fr-par.scw.cloud" }
  #   skip_region_validation      = true
  #   skip_credentials_validation = true
  #   skip_metadata_api_check     = true
  #   skip_requesting_account_id  = true
  #   use_path_style              = true
  #   use_lockfile                = true
  # }
}
