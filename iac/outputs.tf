# --- Outputs ---

output "resource_group_id" {
  description = "Resource ID of the resource group."
  value       = local.resource_group_id
}

output "app_gateway_id" {
  description = "Resource ID of the Application Gateway."
  value       = module.app_gateway.resource_id
}

output "app_gateway_name" {
  description = "Name of the Application Gateway."
  value       = local.agw_name
}

output "public_ip_address" {
  description = "Public IP address of the Application Gateway (null if private_only)."
  value       = local.has_public_frontend ? module.public_ip_agw[0].public_ip_address : null
}

output "private_ip_address" {
  description = "Private IP address of the Application Gateway (null if public_only)."
  value       = local.has_private_frontend ? var.private_ip_address : null
}

output "user_assigned_identity_id" {
  description = "Resource ID of the App Gateway's managed identity."
  value       = azurerm_user_assigned_identity.agw.id
}

output "user_assigned_identity_principal_id" {
  description = "Principal ID of the App Gateway's managed identity (for RBAC assignments)."
  value       = azurerm_user_assigned_identity.agw.principal_id
}

output "global_waf_policy_id" {
  description = "Resource ID of the global WAF policy (null if Standard_v2)."
  value       = var.sku == "WAF_v2" ? module.global_waf_policy[0].resource_id : null
}

output "subnet_id" {
  description = "Resource ID of the App Gateway subnet."
  value       = local.effective_subnet_id
}
