# --- Core variables ---
# These follow the Datacom workload template pattern.

variable "subscription_id" {
  type        = string
  description = "The Azure subscription ID to deploy into."
}

variable "workload_name" {
  type        = string
  description = "Workload name used in resource naming. Kebab-case, 3-32 characters."

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,30}[a-z0-9]$", var.workload_name))
    error_message = "workload_name must be 3-32 lowercase alphanumeric characters or hyphens."
  }
}

variable "env_code" {
  type        = string
  description = "Environment code for naming and tagging."
  default     = "dev"

  validation {
    condition     = contains(["sbx", "dev", "test", "uat", "prod"], var.env_code)
    error_message = "env_code must be one of: sbx, dev, test, uat, prod."
  }
}

variable "location" {
  type        = string
  description = "Azure region for resource deployment."
  default     = "australiaeast"
}

variable "short_location_code" {
  type        = string
  description = "Short location code for naming conventions (e.g. aue, auc)."
  default     = "aue"
}

variable "default_tags" {
  type        = map(string)
  description = "Tags applied to all resources."
  default     = {}
}

variable "use_existing_rg" {
  type        = bool
  description = "When true, uses an existing resource group (enterprise/vending mode). When false, creates a new one."
  default     = true
}

variable "resource_group_name" {
  type        = string
  description = "Override the computed resource group name. Required when use_existing_rg is true."
  default     = null
}
