# --- Data sources ---
# Look up existing resources when operating in enterprise/vending mode.

data "azurerm_client_config" "current" {}

data "azurerm_resource_group" "existing" {
  count = var.use_existing_rg ? 1 : 0
  name  = local.resource_group_name
}

# Look up existing VNet (when not creating locally)
data "azurerm_virtual_network" "existing" {
  count               = var.create_virtual_network ? 0 : 1
  name                = reverse(split("/", var.virtual_network_id))[0]
  resource_group_name = reverse(split("/", var.virtual_network_id))[4]
}

# Look up existing subnet (when provided)
data "azurerm_subnet" "existing" {
  count                = var.existing_subnet_id != null ? 1 : 0
  name                 = reverse(split("/", var.existing_subnet_id))[0]
  virtual_network_name = reverse(split("/", var.existing_subnet_id))[2]
  resource_group_name  = reverse(split("/", var.existing_subnet_id))[6]
}
