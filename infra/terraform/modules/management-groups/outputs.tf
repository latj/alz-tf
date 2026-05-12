output "root_management_group_id" {
  description = "Root management group resource ID"
  value       = azurerm_management_group.root.id
}

output "root_management_group_name" {
  description = "Root management group name"
  value       = azurerm_management_group.root.name
}

output "platform_management_group_id" {
  description = "Platform management group resource ID"
  value       = azurerm_management_group.platform.id
}

output "platform_management_group_name" {
  description = "Platform management group name"
  value       = azurerm_management_group.platform.name
}

output "landing_zones_management_group_id" {
  description = "Landing zones management group resource ID"
  value       = azurerm_management_group.landing_zones.id
}

output "landing_zones_management_group_name" {
  description = "Landing zones management group name"
  value       = azurerm_management_group.landing_zones.name
}

output "prod_management_group_id" {
  description = "Production landing zone management group resource ID"
  value       = azurerm_management_group.prod.id
}

output "prod_management_group_name" {
  description = "Production landing zone management group name"
  value       = azurerm_management_group.prod.name
}

output "nonprod_management_group_id" {
  description = "Non-production landing zone management group resource ID"
  value       = azurerm_management_group.nonprod.id
}

output "nonprod_management_group_name" {
  description = "Non-production landing zone management group name"
  value       = azurerm_management_group.nonprod.name
}
