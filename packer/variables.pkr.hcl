// Input variables for base.pkr.hcl.
//
// Credentials are read from env by default — set SCW_ACCESS_KEY, SCW_SECRET_KEY,
// SCW_DEFAULT_PROJECT_ID before running. Pass `image_version` explicitly when
// building a release (typically the sabokit git tag without the `v`).

variable "scaleway_access_key" {
  type        = string
  description = "Scaleway API access key. Defaults to SCW_ACCESS_KEY env var."
  default     = env("SCW_ACCESS_KEY")
  sensitive   = true
}

variable "scaleway_secret_key" {
  type        = string
  description = "Scaleway API secret key. Defaults to SCW_SECRET_KEY env var."
  default     = env("SCW_SECRET_KEY")
  sensitive   = true
}

variable "scaleway_project_id" {
  type        = string
  description = "Scaleway project the build instance and resulting image live in."
  default     = env("SCW_DEFAULT_PROJECT_ID")
}

variable "scaleway_zone" {
  type        = string
  description = "Scaleway zone the build instance runs in."
  default     = "fr-par-1"
}

variable "source_image" {
  type        = string
  description = "Marketplace label of the source image. ubuntu_jammy = Ubuntu 22.04 LTS."
  default     = "ubuntu_jammy"
}

variable "instance_type" {
  type        = string
  description = "Instance type used for the build. DEV1-S is cheap and plenty for an apt-install workload."
  default     = "DEV1-S"
}

variable "image_name_prefix" {
  type        = string
  description = "Prefix for the resulting image name. Final name is `<prefix>-<version>`."
  default     = "fc-base"
}

variable "image_version" {
  type        = string
  description = "Version tag baked into the image name and into /etc/fc-base-image. Typically the sabokit release tag without the leading 'v' (e.g. \"1.4.0\"). Required."
}

variable "node_exporter_version" {
  type        = string
  description = "node_exporter release to bake. Pinned because we want reproducible images."
  default     = "1.8.2"
}

variable "cadvisor_version" {
  type        = string
  description = "cAdvisor release to bake. Pinned for reproducibility."
  default     = "0.49.1"
}

variable "scw_cli_version" {
  type        = string
  description = "Scaleway CLI release to bake. Pinned for reproducibility — Ansible will upgrade in-place if a newer one is configured."
  default     = "2.34.0"
}
