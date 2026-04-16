# --- Application Gateway variables ---

variable "sku" {
  type        = string
  description = "App Gateway SKU. WAF_v2 enables WAF; Standard_v2 does not."
  default     = "WAF_v2"

  validation {
    condition     = contains(["Standard_v2", "WAF_v2"], var.sku)
    error_message = "sku must be Standard_v2 or WAF_v2."
  }
}

variable "frontend_mode" {
  type        = string
  description = "Frontend IP exposure mode: public_only, private_only, or public_and_private."
  default     = "public_only"

  validation {
    condition     = contains(["public_only", "private_only", "public_and_private"], var.frontend_mode)
    error_message = "frontend_mode must be public_only, private_only, or public_and_private."
  }
}

variable "private_ip_address" {
  type        = string
  description = "Static private IP for the private frontend. Required when frontend_mode includes private."
  default     = null
}

variable "enable_private_link" {
  type        = bool
  description = "Enable Private Link on the App Gateway frontend for cross-subscription consumer access."
  default     = false
}

variable "private_link_subnet_id" {
  type        = string
  description = "Subnet ID for Private Link configuration. Must be separate from the App Gateway subnet."
  default     = null
}

variable "zones" {
  type        = list(number)
  description = "Availability zones for the App Gateway and Public IP."
  default     = [1, 2, 3]
}

variable "autoscale_configuration" {
  type = object({
    min_capacity = number
    max_capacity = number
  })
  description = "Autoscale capacity bounds."
  default = {
    min_capacity = 0
    max_capacity = 2
  }
}

# --- WAF settings ---

variable "waf_mode" {
  type        = string
  description = "WAF mode. Start with Detection for tuning; switch to Prevention when ready."
  default     = "Detection"

  validation {
    condition     = contains(["Detection", "Prevention"], var.waf_mode)
    error_message = "waf_mode must be Detection or Prevention."
  }
}

variable "waf_ruleset_type" {
  type        = string
  description = "WAF managed ruleset type."
  default     = "OWASP"
}

variable "waf_ruleset_version" {
  type        = string
  description = "WAF managed ruleset version."
  default     = "3.2"
}

# --- SSL / Key Vault ---

variable "ssl_keyvault_principal_ids" {
  type        = list(string)
  description = "Object IDs of Entra principals (groups or users) with access to the SSL certificate Key Vault. The App Gateway UMI will be added to these groups."
  default     = []
}

variable "ssl_policy" {
  type = object({
    min_protocol_version = optional(string, "TLSv1_2")
    policy_type          = optional(string, "CustomV2")
    cipher_suites = optional(list(string), [
      "TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384",
      "TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256",
      "TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384",
      "TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256",
    ])
  })
  description = "TLS policy configuration. Defaults to TLS 1.2+ with modern ECDHE ciphers."
  default     = {}
}

# --- App configuration directory ---

variable "app_config_dir" {
  type        = string
  description = "Path to the directory containing application YAML configuration files, relative to the iac/ root."
  default     = null
}
