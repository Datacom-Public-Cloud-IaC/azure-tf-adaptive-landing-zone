# PoC / Standalone deployment
# Creates VNet, subnet, NSG, and RG locally. No vending required.

subscription_id    = "00000000-0000-0000-0000-000000000000"
workload_name      = "shared-appgw"
env_code           = "sbx"
location           = "australiaeast"
short_location_code = "aue"

# PoC: create all networking locally
use_existing_rg               = false
create_virtual_network        = true
virtual_network_address_space = ["10.100.0.0/24"]
subnet_address_space          = ["10.100.0.0/26"]

# Simple public gateway with minimal capacity
frontend_mode = "public_only"
sku           = "WAF_v2"
waf_mode      = "Detection"

autoscale_configuration = {
  min_capacity = 0
  max_capacity = 2
}

zones = [1, 2, 3]

# Point app_config_dir at the example apps
app_config_dir = "environments/examples/apps"

default_tags = {
  ApplicationName = "Shared App Gateway"
  DeployedBy      = "Terraform"
  Environment     = "Sandbox"
  CostCentre      = "TODO"
}
