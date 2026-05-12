output "hub_vnet_id" {
  description = "Hub virtual network resource ID"
  value       = azurerm_virtual_network.hub.id
}

output "hub_vnet_name" {
  description = "Hub virtual network name"
  value       = azurerm_virtual_network.hub.name
}

output "firewall_private_ip" {
  description = "Azure Firewall private IP address"
  value       = azurerm_firewall.this.ip_configuration[0].private_ip_address
}

output "firewall_public_ip" {
  description = "Azure Firewall public IP address"
  value       = azurerm_public_ip.firewall.ip_address
}

output "firewall_policy_id" {
  description = "Azure Firewall Policy resource ID"
  value       = azurerm_firewall_policy.this.id
}

output "private_dns_resolver_inbound_ips" {
  description = "Private DNS Resolver inbound endpoint IP addresses"
  value       = azurerm_private_dns_resolver_inbound_endpoint.this.ip_configurations[*].private_ip_address
}

output "private_dns_zones" {
  description = "Private DNS zones created"
  value       = [for zone in azurerm_private_dns_zone.this : zone.name]
}
