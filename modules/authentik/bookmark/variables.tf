variable "application_name" {
  description = "Display name shown in the Authentik user portal."
  type        = string
}

variable "application_slug" {
  description = "URL-safe slug."
  type        = string
}

variable "category_group" {
  description = "Category shown in the user portal grid. Free text."
  type        = string
  default     = "Resources"
}

variable "launch_url" {
  description = "URL the bookmark opens (required for bookmarks). Pass a full URL."
  type        = string
}

variable "icon_url" {
  description = "Optional icon path or full URL."
  type        = string
  default     = null
}

variable "description" {
  description = "Optional one-line bookmark description."
  type        = string
  default     = null
}

variable "authorized_group_ids" {
  description = "Authentik group IDs allowed to see this bookmark. The module creates one policy binding per group."
  type        = list(string)

  validation {
    condition     = length(var.authorized_group_ids) > 0
    error_message = "At least one authorized group ID must be provided."
  }
}

variable "open_in_new_tab" {
  description = "Whether the bookmark opens in a new browser tab."
  type        = bool
  default     = true
}
