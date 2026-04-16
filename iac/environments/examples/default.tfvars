# Enterprise Landing Zone deployment
# Uses vending-provided VNet, subnet, and resource group.

subscription_id    = "00000000-0000-0000-0000-000000000000"
workload_name      = "shared-appgw"
env_code           = "prod"
location           = "australiaeast"
short_location_code = "aue"

# Enterprise: use vended resources
use_existing_rg    = true
resource_group_name = "rg-shared-appgw-prod-aue"

create_virtual_network = false
virtual_network_id     = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-connectivity-prod-aue/providers/Microsoft.Network/virtualNetworks/vnet-connectivity-prod-aue"
existing_subnet_id     = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-connectivity-prod-aue/providers/Microsoft.Network/virtualNetworks/vnet-connectivity-prod-aue/subnets/snet-appgw-prod-aue"

# Public + Private frontend (hybrid)
frontend_mode      = "public_and_private"
private_ip_address = "10.0.4.10"

# WAF in Detection initially — switch to Prevention after tuning
sku      = "WAF_v2"
waf_mode = "Detection"

autoscale_configuration = {
  min_capacity = 1
  max_capacity = 10
}

zones = [1, 2, 3]

# SSL: Entra group object IDs with Key Vault access
ssl_keyvault_principal_ids = ["00000000-0000-0000-0000-000000000000"]

default_tags = {
  ApplicationName = "Shared App Gateway"
  DeployedBy      = "Terraform"
  Environment     = "Production"
  CostCentre      = "TODO"
  Owner           = "Platform Team"
}
