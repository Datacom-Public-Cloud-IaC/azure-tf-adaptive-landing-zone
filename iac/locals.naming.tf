# --- Naming conventions ---
# Pattern: {workload}-{env}-{location}-{type}

locals {
  workload_name        = var.workload_name
  short_workload_name  = substr(replace(local.workload_name, "-", ""), 0, 16)
  default_suffix       = "${local.workload_name}-${var.env_code}-${var.short_location_code}"
  default_short_suffix = lower("${local.short_workload_name}${var.env_code}")

  # Resource names — all overridable via variables
  resource_group_name         = coalesce(var.resource_group_name, "${local.default_suffix}-rg")
  virtual_network_name        = coalesce(var.virtual_network_name, "${local.default_suffix}-vnet")
  subnet_name                 = coalesce(var.subnet_name, "${local.default_suffix}-sn")
  network_security_group_name = coalesce(var.network_security_group_name, "${local.default_suffix}-nsg")

  # App Gateway specific names
  agw_name  = "agw-${local.default_suffix}"
  pip_name  = "pip-${local.default_suffix}"
  umi_name  = "id-agw-${local.default_suffix}"
  waf_name  = "waf-${local.default_suffix}"

  # Per-app WAF policy name format
  waf_app_name_format = "waf-${local.default_suffix}-%s"
}
