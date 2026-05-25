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
  description = "Full icon URL override. When set, used verbatim and `icon_filename` is ignored. Empty falls back to `$${icon_base_url}/$${icon_filename}` (or `default-logo.png` when `icon_filename` is also empty)."
  type        = string
  default     = ""
}

variable "icon_filename" {
  description = "Icon filename fetched from `icon_base_url`. Empty disables the composed URL. Overridden by `icon_url`."
  type        = string
  default     = ""
}

variable "icon_base_url" {
  description = "Base URL the bookmark composes `$${icon_base_url}/$${icon_filename}` from when `icon_url` is empty. Typically `var.base.authentik.icon_base_url` from the platform identity output."
  type        = string
  default     = ""
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
