# --- Resource group ---

resource "azurerm_resource_group" "this" {
  count    = var.use_existing_rg ? 0 : 1
  name     = local.resource_group_name
  location = var.location
  tags     = local.tags
}
