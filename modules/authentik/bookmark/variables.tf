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

variable "authorized_groups" {
  description = "Map of role-name → Authentik group ID for groups allowed to see this bookmark. Keys MUST be static strings (e.g. \"admin\", \"member\", \"delegate\") so for_each can plan even when group IDs are not yet known. The module creates one policy binding per entry."
  type        = map(string)

  validation {
    condition     = length(var.authorized_groups) > 0
    error_message = "At least one authorized group must be provided. To restrict the bookmark to administrators only, pass { admin = base.authentik.groups[\"admin\"] }."
  }
}

variable "open_in_new_tab" {
  description = "Whether the bookmark opens in a new browser tab."
  type        = bool
  default     = true
}
