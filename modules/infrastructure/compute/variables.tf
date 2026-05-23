variable "instance_name" {
  description = "Name of the instance"
  type        = string
}

variable "instance_type" {
  description = "Instance type"
  type        = string
  default     = "DEV1-S"
}

variable "image" {
  description = "Base image. Either a Scaleway marketplace label (default \"ubuntu_jammy\") or a Scaleway image UUID — most commonly an imported fc-base-<version> custom image (see packer/ + consumer-template/scripts/import-base-image.sh)."
  type        = string
  default     = "ubuntu_jammy"
}

variable "disk_size" {
  description = "Root volume size in GB"
  type        = number
  default     = 30
}

variable "disk_type" {
  description = "Root volume type"
  type        = string
  default     = "l_ssd"
  validation {
    condition     = contains(["l_ssd", "sbs_volume"], var.disk_type)
    error_message = "Invalid disk type. Must be one of: l_ssd, sbs_volume."
  }
}

variable "private_network_id" {
  description = "Private network ID"
  type        = string
}

variable "protected" {
  description = "Protect the instance from deletion"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags to apply to the instance"
  type        = list(string)
  default     = []
}

variable "security_group_id" {
  description = "Security group ID to assign to this instance"
  type        = string
}

variable "additional_volume_ids" {
  description = "List of additional volume IDs to attach to the instance"
  type        = list(string)
  default     = []
}

variable "user_data" {
  description = "Map of cloud-init / user_data entries passed to the instance. Common keys: 'cloud-init' (yaml string), 'cloud-config' (yaml string). Empty map = no first-boot bootstrap."
  type        = map(string)
  default     = {}
}