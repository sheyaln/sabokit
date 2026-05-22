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
  type      = string
  sensitive = true
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
