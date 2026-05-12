# ==============================================================================
# Outputs
# ==============================================================================

output "resource_group_monitoring" {
  description = "Monitoring resource group name"
  value       = var.management_subscription_id != "" ? azurerm_resource_group.monitoring[0].name : null
}

output "resource_group_networking" {
  description = "Networking resource group name"
  value       = var.networking_subscription_id != "" ? azurerm_resource_group.networking[0].name : null
}

output "log_analytics_workspace_id" {
  description = "Log Analytics workspace resource ID"
  value       = var.management_subscription_id != "" ? module.log_analytics[0].workspace_id : null
}

output "log_analytics_workspace_name" {
  description = "Log Analytics workspace name"
  value       = var.management_subscription_id != "" ? module.log_analytics[0].workspace_name : null
}

output "hub_vnet_id" {
  description = "Hub virtual network resource ID"
  value       = var.networking_subscription_id != "" ? module.networking[0].hub_vnet_id : null
}

output "hub_vnet_name" {
  description = "Hub virtual network name"
  value       = var.networking_subscription_id != "" ? module.networking[0].hub_vnet_name : null
}

output "firewall_private_ip" {
  description = "Azure Firewall private IP address"
  value       = var.networking_subscription_id != "" ? module.networking[0].firewall_private_ip : null
}

output "firewall_public_ip" {
  description = "Azure Firewall public IP address"
  value       = var.networking_subscription_id != "" ? module.networking[0].firewall_public_ip : null
}

output "private_dns_zones" {
  description = "Private DNS zones created"
  value       = var.networking_subscription_id != "" ? module.networking[0].private_dns_zones : null
}

output "root_management_group_id" {
  description = "Root management group resource ID"
  value       = var.enable_management_groups ? module.management_groups[0].root_management_group_id : null
}

output "platform_management_group_id" {
  description = "Platform management group resource ID"
  value       = var.enable_management_groups ? module.management_groups[0].platform_management_group_id : null
}

output "landing_zones_management_group_id" {
  description = "Landing zones management group resource ID"
  value       = var.enable_management_groups ? module.management_groups[0].landing_zones_management_group_id : null
}

output "prod_management_group_id" {
  description = "Production landing zone management group resource ID"
  value       = var.enable_management_groups ? module.management_groups[0].prod_management_group_id : null
}

output "nonprod_management_group_id" {
  description = "Non-production landing zone management group resource ID"
  value       = var.enable_management_groups ? module.management_groups[0].nonprod_management_group_id : null
}
