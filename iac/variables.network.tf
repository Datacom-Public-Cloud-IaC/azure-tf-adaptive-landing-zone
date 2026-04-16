# --- Network variables ---
# Supports three scenarios:
#   1. Full vending: existing VNet + existing subnet + existing NSG
#   2. Hybrid: existing VNet + create subnet/NSG locally
#   3. PoC: create everything locally

variable "create_virtual_network" {
  type        = bool
  description = "When true, creates a new VNet locally (PoC mode). When false, uses an existing VNet."
  default     = false
}

variable "virtual_network_id" {
  type        = string
  description = "Resource ID of an existing VNet (from vending). Required when create_virtual_network is false."
  default     = null

  validation {
    condition     = var.virtual_network_id == null || can(regex("^/subscriptions/[^/]+/resourceGroups/[^/]+/providers/Microsoft.Network/virtualNetworks/[^/]+$", var.virtual_network_id))
    error_message = "virtual_network_id must be a valid VNet resource ID."
  }
}

variable "virtual_network_name" {
  type        = string
  description = "Override the computed VNet name (used when creating locally)."
  default     = null
}

variable "virtual_network_address_space" {
  type        = list(string)
  description = "Address space for the VNet. Required when create_virtual_network is true."
  default     = []
}

variable "virtual_network_dns_servers" {
  type        = list(string)
  description = "Custom DNS servers for the VNet."
  default     = []
}

variable "existing_subnet_id" {
  type        = string
  description = "Resource ID of an existing App Gateway subnet. When null, creates a new subnet."
  default     = null

  validation {
    condition     = var.existing_subnet_id == null || can(regex("/subnets/[^/]+$", var.existing_subnet_id))
    error_message = "existing_subnet_id must be a valid subnet resource ID."
  }
}

variable "subnet_name" {
  type        = string
  description = "Override the computed subnet name."
  default     = null
}

variable "subnet_address_space" {
  type        = list(string)
  description = "Address prefix for the App Gateway subnet. /24 recommended for v2 SKU. Required when creating subnet."
  default     = []
}

variable "existing_network_security_group_id" {
  type        = string
  description = "Resource ID of an existing NSG. When null, creates a baseline NSG."
  default     = null
}

variable "network_security_group_name" {
  type        = string
  description = "Override the computed NSG name."
  default     = null
}
