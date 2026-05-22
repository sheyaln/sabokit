
# Secrets Module - Variables


variable "secrets" {
  description = "Map of secret categories to secret configurations"
  type = map(list(object({
    name        = string
    description = string
    type        = string
    path        = optional(string, "/")
    generate    = optional(bool, false)
    length      = optional(number, 32)
    value       = optional(string)
    tags        = optional(list(string), [])
  })))
  default = {}
}

variable "project_config" {
  description = "Project configuration from config/project.yml for templating secret values"
  type        = any
  default     = {}
}
