# --- Application Gateway resources ---
# UMI, WAF policies, Public IP, and the App Gateway itself.

# --- User-Assigned Managed Identity ---
# Used for Key Vault certificate access.
resource "azurerm_user_assigned_identity" "agw" {
  name                = local.umi_name
  location            = local.resource_group_location
  resource_group_name = var.use_existing_rg ? data.azurerm_resource_group.existing[0].name : azurerm_resource_group.this[0].name
  tags                = local.tags
}

# Add UMI to Entra groups that have Key Vault access (for SSL certificates)
resource "azuread_group_member" "ssl_keyvault" {
  for_each = toset(var.ssl_keyvault_principal_ids)

  group_object_id  = each.value
  member_object_id = azurerm_user_assigned_identity.agw.principal_id
}

# --- Global WAF Policy ---
# Baseline WAF applied to all listeners. Only deployed for WAF_v2 SKU.
module "global_waf_policy" {
  count = var.sku == "WAF_v2" ? 1 : 0

  source = "git::https://github.com/kewalaka/terraform-azurerm-avm-res-network-applicationgatewaywebapplicationfirewallpolicy.git?ref=feat/azapi"

  name      = local.waf_name
  parent_id = local.resource_group_id
  location  = local.resource_group_location

  policy_settings = {
    enabled                                   = true
    mode                                      = var.waf_mode
    request_body_check                        = true
    file_upload_limit_in_mb                   = 100
    max_request_body_size_in_kb               = 128
    request_body_inspect_limit_in_kb          = 128
    js_challenge_cookie_expiration_in_minutes = 30
  }

  managed_rules = {
    managed_rule_set = {
      owasp = {
        type    = var.waf_ruleset_type
        version = var.waf_ruleset_version
      }
    }
  }

  enable_telemetry = false
  tags             = local.tags
}

# --- Per-Application WAF Policies ---
# Optional overrides defined in YAML waf_config sections.
module "app_waf_policies" {
  for_each = local.waf_config

  source = "git::https://github.com/kewalaka/terraform-azurerm-avm-res-network-applicationgatewaywebapplicationfirewallpolicy.git?ref=feat/azapi"

  name      = format(local.waf_app_name_format, each.value.waf_name_part)
  parent_id = local.resource_group_id
  location  = local.resource_group_location

  managed_rules   = each.value.managed_rules
  policy_settings = try(each.value.policy_settings, local.waf_policy_settings_default)
  custom_rules    = try(each.value.custom_rules, null)

  enable_telemetry = false
  tags             = local.tags
}

# --- Public IP ---
# Created when the gateway has a public frontend.
module "public_ip_agw" {
  count   = local.has_public_frontend ? 1 : 0
  source  = "Azure/avm-res-network-publicipaddress/azurerm"
  version = "0.1.2"

  resource_group_name = var.use_existing_rg ? data.azurerm_resource_group.existing[0].name : azurerm_resource_group.this[0].name
  name                = local.pip_name
  location            = local.resource_group_location

  allocation_method = "Static"
  sku               = "Standard"
  sku_tier          = "Regional"
  zones             = var.zones

  tags = local.tags
}

# --- Application Gateway ---
module "app_gateway" {
  source = "git::https://github.com/kewalaka/terraform-azurerm-avm-res-network-applicationgateway.git?ref=feat/azapi-migration"

  location  = local.resource_group_location
  name      = local.agw_name
  parent_id = local.resource_group_id

  backend_address_pools            = local.backend_address_pools
  backend_http_settings_collection = local.backend_http_settings
  frontend_ip_configurations       = local.frontend_ip_configurations
  frontend_ports                   = local.frontend_ports
  gateway_ip_configurations        = local.gateway_ip_configurations
  http_listeners                   = local.http_listeners
  request_routing_rules            = local.request_routing_rules
  probes                           = local.health_probes
  redirect_configurations          = local.redirect_configurations
  ssl_certificates                 = local.ssl_certificates
  trusted_root_certificates        = local.trusted_root_certificates
  url_path_maps                    = local.url_path_maps

  firewall_policy = var.sku == "WAF_v2" ? {
    id = module.global_waf_policy[0].resource_id
  } : null

  sku = {
    name = var.sku
    tier = var.sku
  }

  autoscale_configuration = var.autoscale_configuration

  ssl_policy = {
    min_protocol_version = var.ssl_policy.min_protocol_version
    policy_type          = var.ssl_policy.policy_type
    cipher_suites        = var.ssl_policy.cipher_suites
  }

  managed_identities = {
    system_assigned = false
    user_assigned_resource_ids = [
      azurerm_user_assigned_identity.agw.id
    ]
  }

  zones = [for z in var.zones : tostring(z)]

  enable_telemetry = false
  tags             = local.tags

  depends_on = [
    module.public_ip_agw,
    module.app_waf_policies,
    module.avm_res_network_subnet,
  ]
}
