variable "name" {
  description = "Name of the private network."
  type        = string
}

variable "region" {
  description = "Scaleway region."
  type        = string
  default     = "fr-par"
}

variable "tags" {
  description = "Tags applied to the private network."
  type        = list(string)
  default     = []
}

variable "vpc_id" {
  description = "Optional: ID of an existing VPC. If null, the private network is created in the project's default VPC."
  type        = string
  default     = null
}

variable "subnet" {
  description = "Optional: explicit IPv4 CIDR for the private network. If null, Scaleway assigns one automatically."
  type        = string
  default     = null
}
