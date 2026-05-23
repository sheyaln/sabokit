# Per-env inputs. Pass via terraform.tfvars (gitignored) or TF_VAR_* env vars.

variable "scaleway_access_key" {
  type      = string
  sensitive = true
}

variable "scaleway_secret_key" {
  type      = string
  sensitive = true
}

variable "scaleway_project_id" {
  type = string
}

variable "scaleway_region" {
  type    = string
  default = "fr-par"
}

variable "scaleway_zone" {
  type    = string
  default = "fr-par-1"
}

variable "authentik_admin_token" {
  description = "Authentik admin API token. Empty during the first-phase apply (when Authentik doesn't exist yet); deploy.sh fetches it from the bootstrap admin secret and re-exports as TF_VAR_authentik_admin_token before the second phase. Setting it manually in terraform.tfvars is not recommended."
  type        = string
  sensitive   = true
  default     = ""
}

variable "org_slug" {
  type = string
}

variable "org_name" {
  type = string
}

variable "environment" {
  type    = string
  default = "prod"
}

variable "base_domain" {
  type = string
}

variable "mgmt_domain" {
  type    = string
  default = null
}

variable "gateway_domain" {
  type = string
}

variable "infra_email" {
  type = string
}

variable "private_network_subnet" {
  type    = string
  default = "10.0.0.0/22"
}

variable "compute_hosts" {
  type = map(object({
    instance_type     = string
    image             = optional(string, "ubuntu_jammy")
    disk_size         = optional(number, 30)
    disk_type         = optional(string, "sbs_volume")
    role              = string
    ansible_group     = string
    ansible_groups    = optional(list(string), [])
    protected         = optional(bool, false)
    user_data         = optional(map(string), {})
    security_group_id = optional(string, null)
    tags              = optional(list(string), [])
  }))
  default = {
    apps = {
      instance_type = "DEV1-L"
      disk_size     = 100
      role          = "apps"
      ansible_group = "apps"
      protected     = true
    }
  }
}

variable "apps" {
  type    = any
  default = {}
}

variable "smtp_secret_name" {
  type    = string
  default = ""
}

variable "manage_gateway_dns" {
  type    = bool
  default = true
}

variable "gateway_compute_host_key" {
  type    = string
  default = null
}
