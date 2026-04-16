# --- Resource resolution ---
# Resolves resource references based on create-vs-use-existing decisions.

locals {
  # Resource group
  resource_group_location = var.use_existing_rg ? data.azurerm_resource_group.existing[0].location : azurerm_resource_group.this[0].location
  resource_group_id       = var.use_existing_rg ? data.azurerm_resource_group.existing[0].id : azurerm_resource_group.this[0].id

  # Virtual network
  effective_virtual_network_id = var.create_virtual_network ? module.avm_res_network_vnet[0].resource_id : var.virtual_network_id

  # Subnet
  effective_subnet_id = var.existing_subnet_id != null ? var.existing_subnet_id : module.avm_res_network_subnet[0].resource_id

  # NSG
  effective_nsg_id = var.existing_network_security_group_id != null ? var.existing_network_security_group_id : module.avm_res_network_nsg[0].resource_id

  # Tags
  tags = merge(var.default_tags, {
    Environment  = var.env_code
    LocationCode = var.short_location_code
    Workload     = var.workload_name
  })

  # Frontend IP configuration helpers
  has_public_frontend  = var.frontend_mode != "private_only"
  has_private_frontend = var.frontend_mode != "public_only"
}
