variable "application_name" {
  description = "Display name for the bookmark application"
  type        = string
}

variable "application_slug" {
  description = "URL-friendly slug for the bookmark application"
  type        = string
}

variable "category_group" {
  description = "Category group for the application"
  type        = string
  default     = "Member Resources"
}

variable "launch_url" {
  description = "Launch URL for the bookmark application (required for bookmarks)"
  type        = string
}

variable "icon_url" {
  description = "Icon URL for the application"
  type        = string
  default     = null
}

variable "description" {
  description = "Description for the application"
  type        = string
  default     = null
}

variable "access_level" {
  description = "Access level: admin, delegate, treasurer, or member"
  type        = string
  validation {
    condition     = contains(["admin", "delegate", "treasurer", "member"], var.access_level)
    error_message = "Access level must be one of: admin, delegate, treasurer, member."
  }
}

variable "group_ids" {
  description = "Map of group IDs for access control"
  type = object({
    admin           = string
    union_delegate  = string
    union_treasurer = string
    union_member    = string
  })
}

variable "open_in_new_tab" {
  description = "Whether to open the bookmark in a new tab"
  type        = bool
  default     = true
}
