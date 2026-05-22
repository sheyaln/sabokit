variable "application_name" {
  description = "Display name shown in the Authentik user portal."
  type        = string
}

variable "application_slug" {
  description = "URL-safe slug. Also used to name the per-app Authentik group and Scaleway secret."
  type        = string
}

variable "category_group" {
  description = "Category shown in the user portal grid. Free text."
  type        = string
  default     = "Tools"
}

variable "launch_url" {
  description = "Optional launch URL shown in the user portal."
  type        = string
  default     = null
}

variable "icon_url" {
  description = "Optional icon path (relative to Authentik media) or full URL."
  type        = string
  default     = null
}

variable "description" {
  description = "Optional one-line app description shown in the user portal."
  type        = string
  default     = null
}

variable "authorized_group_ids" {
  description = "Authentik group IDs allowed to access this application. The module creates one policy binding per group."
  type        = list(string)

  validation {
    condition     = length(var.authorized_group_ids) > 0
    error_message = "At least one authorized group ID must be provided."
  }
}

variable "authentication_flow_uuid" {
  description = "Authentication flow UUID."
  type        = string
}

variable "authorization_flow_uuid" {
  description = "Authorization flow UUID."
  type        = string
}

variable "invalidation_flow_uuid" {
  description = "Invalidation flow UUID."
  type        = string
}

variable "generate_rsa_signing_key" {
  description = "If true, generate a dedicated RSA signing key for SAML assertions. Otherwise use the Authentik default self-signed certificate."
  type        = bool
  default     = false
}

variable "signing_key_subject" {
  description = "Subject for the RSA signing certificate when generate_rsa_signing_key is true."
  type = object({
    common_name  = string
    organization = string
  })
  default = {
    common_name  = "authentik.example.org"
    organization = "Federated Commons"
  }
}

variable "saml_assertion_consumer_service_url" {
  description = "SAML Assertion Consumer Service (ACS) URL on the service provider side. Pass a full URL; the module never assembles subdomains."
  type        = string
}

variable "saml_audience" {
  description = "SAML audience / entity ID expected by the service provider."
  type        = string
}

variable "saml_service_provider_binding" {
  description = "SAML service provider binding. 'redirect' or 'post'."
  type        = string
  default     = "redirect"

  validation {
    condition     = contains(["redirect", "post"], var.saml_service_provider_binding)
    error_message = "SAML service provider binding must be either 'redirect' or 'post'."
  }
}

variable "saml_name_id_mapping" {
  description = "Property mapping ID for the SAML NameID. Defaults to Authentik's default if null. Ignored when saml_name_id_use_email = true."
  type        = string
  default     = null
}

variable "saml_name_id_use_email" {
  description = "If true, use the email property mapping as the SAML NameID."
  type        = bool
  default     = false
}

variable "saml_digest_algorithm" {
  description = "SAML digest algorithm."
  type        = string
  default     = "http://www.w3.org/2001/04/xmlenc#sha256"
}

variable "saml_signature_algorithm" {
  description = "SAML signature algorithm."
  type        = string
  default     = "http://www.w3.org/2001/04/xmldsig-more#rsa-sha256"
}

variable "saml_sign_assertion" {
  description = "Whether to sign SAML assertions."
  type        = bool
  default     = true
}

variable "saml_default_relay_state" {
  description = "Optional default relay state passed to the SP."
  type        = string
  default     = null
}

variable "include_groups_attribute" {
  description = "Whether to include the SAML groups attribute mapping in assertions."
  type        = bool
  default     = true
}
