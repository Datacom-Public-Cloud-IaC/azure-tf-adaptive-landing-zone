# --- Networking ---
# VNet, App Gateway subnet, and NSG via AVM modules.
# Supports full vending, hybrid, and PoC creation scenarios.

# --- Virtual Network (PoC mode only) ---
module "avm_res_network_vnet" {
  count   = var.create_virtual_network ? 1 : 0
  source  = "Azure/avm-res-network-virtualnetwork/azurerm"
  version = "0.17.1"

  name                = local.virtual_network_name
  resource_group_name = var.use_existing_rg ? data.azurerm_resource_group.existing[0].name : azurerm_resource_group.this[0].name
  location            = local.resource_group_location
  address_space       = var.virtual_network_address_space
  dns_servers = length(var.virtual_network_dns_servers) > 0 ? {
    dns_servers = var.virtual_network_dns_servers
  } : null

  tags = local.tags
}

# --- Network Security Group ---
# Baseline NSG for the App Gateway subnet with required rules.
module "avm_res_network_nsg" {
  count   = var.existing_network_security_group_id == null ? 1 : 0
  source  = "Azure/avm-res-network-networksecuritygroup/azurerm"
  version = "0.5.1"

  name                = local.network_security_group_name
  resource_group_name = var.use_existing_rg ? data.azurerm_resource_group.existing[0].name : azurerm_resource_group.this[0].name
  location            = local.resource_group_location

  security_rules = {
    # Required: Allow Azure Gateway Manager health probes
    allow_gateway_manager = {
      name                       = "AllowGatewayManagerInBound"
      priority                   = 100
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "65200-65535"
      source_address_prefix      = "GatewayManager"
      destination_address_prefix = "*"
    }
    # Required: Allow Azure Load Balancer probes
    allow_load_balancer = {
      name                       = "AllowAzureLoadBalancerInBound"
      priority                   = 110
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "*"
      source_port_range          = "*"
      destination_port_range     = "*"
      source_address_prefix      = "AzureLoadBalancer"
      destination_address_prefix = "*"
    }
    # Allow HTTP inbound (for redirect to HTTPS)
    allow_http = {
      name                       = "AllowHttpInBound"
      priority                   = 200
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "80"
      source_address_prefix      = "*"
      destination_address_prefix = "*"
    }
    # Allow HTTPS inbound
    allow_https = {
      name                       = "AllowHttpsInBound"
      priority                   = 210
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "443"
      source_address_prefix      = "*"
      destination_address_prefix = "*"
    }
  }

  tags = local.tags
}

# --- App Gateway Subnet ---
# Uses the AVM subnet submodule for atomic NSG association.
module "avm_res_network_subnet" {
  count   = var.existing_subnet_id == null ? 1 : 0
  source  = "Azure/avm-res-network-virtualnetwork/azurerm//modules/subnet"
  version = "0.17.1"

  virtual_network = {
    resource_id = local.effective_virtual_network_id
  }

  name             = local.subnet_name
  address_prefixes = var.subnet_address_space

  network_security_group = {
    id = local.effective_nsg_id
  }
}
