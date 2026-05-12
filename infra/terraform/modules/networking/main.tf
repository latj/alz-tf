terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

locals {
  # Hub VNet configuration
  hub_vnet_name     = "vnet-${var.prefix}-hub"
  hub_address_space = var.hub_address_space != "" ? var.hub_address_space : "10.0.0.0/16"

  # Common private DNS zones for private endpoints
  private_dns_zones = [
    "privatelink.blob.core.windows.net",
    "privatelink.file.core.windows.net",
    "privatelink.queue.core.windows.net",
    "privatelink.table.core.windows.net",
    "privatelink.vaultcore.azure.net",
    "privatelink.database.windows.net",
    "privatelink.postgres.database.azure.com",
    "privatelink.mysql.database.azure.com",
    "privatelink.redis.cache.windows.net",
    "privatelink.servicebus.windows.net",
    "privatelink.eventhub.windows.net",
    "privatelink.webpubsub.azure.com",
    "privatelink.azurewebsites.net",
    "privatelink.api.azureml.ms",
    "privatelink.notebooks.azure.net"
  ]
}

# ==============================================================================
# Hub VNet
# ==============================================================================

resource "azurerm_virtual_network" "hub" {
  name                = local.hub_vnet_name
  location            = var.location
  resource_group_name = var.resource_group_name
  address_space       = [local.hub_address_space]
  tags                = var.tags
}

# Hub subnets
resource "azurerm_subnet" "hub_firewall" {
  name                 = "AzureFirewallSubnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = [cidrsubnet(local.hub_address_space, 3, 0)] # /26
}

resource "azurerm_subnet" "hub_dns_resolver_inbound" {
  name                 = "snet-dns-resolver-inbound"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = [cidrsubnet(local.hub_address_space, 3, 1)] # /26

  delegation {
    name = "Microsoft.Network.dnsResolvers"
    service_delegation {
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action",
      ]
      name = "Microsoft.Network/dnsResolvers"
    }
  }
}

resource "azurerm_subnet" "hub_dns_resolver_outbound" {
  name                 = "snet-dns-resolver-outbound"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = [cidrsubnet(local.hub_address_space, 3, 2)] # /26

  delegation {
    name = "Microsoft.Network.dnsResolvers"
    service_delegation {
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action",
      ]
      name = "Microsoft.Network/dnsResolvers"
    }
  }
}

resource "azurerm_subnet" "hub_gateway" {
  name                 = "GatewaySubnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = [cidrsubnet(local.hub_address_space, 3, 3)] # /26
}

# ==============================================================================
# Azure Firewall
# ==============================================================================

resource "azurerm_public_ip" "firewall" {
  name                = "pip-fw-${var.prefix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

resource "azurerm_firewall_policy" "this" {
  name                = "fwp-${var.prefix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "Standard"
  tags                = var.tags
}

# Application rule collection for outbound traffic
resource "azurerm_firewall_policy_rule_collection_group" "outbound" {
  name               = "DefaultOutboundRules"
  firewall_policy_id = azurerm_firewall_policy.this.id
  priority           = 100

  application_rule_collection {
    name     = "AllowAzureServices"
    priority = 100
    action   = "Allow"

    rule {
      name = "AllowAzureCloud"

      protocols {
        type = "Http"
        port = 80
      }
      protocols {
        type = "Https"
        port = 443
      }

      source_addresses  = ["*"]
      destination_fqdns = ["*.azure.com", "*.microsoft.com", "*.windows.net"]
    }
  }

  network_rule_collection {
    name     = "AllowOutbound"
    priority = 200
    action   = "Allow"

    rule {
      name                  = "AllowNTP"
      protocols             = ["UDP"]
      source_addresses      = ["*"]
      destination_addresses = ["*"]
      destination_ports     = ["123"]
    }

    rule {
      name                  = "AllowDNS"
      protocols             = ["UDP"]
      source_addresses      = ["*"]
      destination_addresses = ["*"]
      destination_ports     = ["53"]
    }
  }
}

resource "azurerm_firewall" "this" {
  name                = "fw-${var.prefix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku_name            = "AZFW_VNet"
  sku_tier            = "Standard"
  firewall_policy_id  = azurerm_firewall_policy.this.id
  tags                = var.tags

  ip_configuration {
    name                 = "configuration"
    subnet_id            = azurerm_subnet.hub_firewall.id
    public_ip_address_id = azurerm_public_ip.firewall.id
  }
}

# ==============================================================================
# Private DNS Resolver
# ==============================================================================

resource "azurerm_private_dns_resolver" "this" {
  name                = "dnsr-${var.prefix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  virtual_network_id  = azurerm_virtual_network.hub.id
  tags                = var.tags
}

resource "azurerm_private_dns_resolver_inbound_endpoint" "this" {
  name                    = "dnsr-inbound-${var.prefix}"
  private_dns_resolver_id = azurerm_private_dns_resolver.this.id
  location                = var.location
  tags                    = var.tags

  ip_configurations {
    private_ip_allocation_method = "Dynamic"
    subnet_id                    = azurerm_subnet.hub_dns_resolver_inbound.id
  }
}

resource "azurerm_private_dns_resolver_outbound_endpoint" "this" {
  name                    = "dnsr-outbound-${var.prefix}"
  private_dns_resolver_id = azurerm_private_dns_resolver.this.id
  location                = var.location
  subnet_id               = azurerm_subnet.hub_dns_resolver_outbound.id
  tags                    = var.tags
}

# Create a DNS Forwarding Ruleset
resource "azurerm_private_dns_resolver_dns_forwarding_ruleset" "this" {
  name                                       = "dnsfrs-${var.prefix}"
  resource_group_name                        = var.resource_group_name
  private_dns_resolver_outbound_endpoint_ids = [azurerm_private_dns_resolver_outbound_endpoint.this.id]
  location                                   = var.location
  tags                                       = var.tags
}

# Forwarding rules for Azure services
resource "azurerm_private_dns_resolver_forwarding_rule" "azure_services" {
  count                     = var.enable_azure_services_forwarding_rule ? 1 : 0
  name                      = "dnsr-fr-azure-services"
  dns_forwarding_ruleset_id = azurerm_private_dns_resolver_dns_forwarding_ruleset.this.id
  domain_name               = "azure.com."
  enabled                   = true

  target_dns_servers {
    ip_address = "168.63.129.16" # Azure DNS
    port       = 53
  }
}

# ==============================================================================
# Private DNS Zones
# ==============================================================================

resource "azurerm_private_dns_zone" "this" {
  for_each            = toset(local.private_dns_zones)
  name                = each.value
  resource_group_name = var.resource_group_name
  # Note: Do not apply tags directly to avoid duplication. Tags from DNS zone links are sufficient.
}

resource "azurerm_private_dns_zone_virtual_network_link" "hub" {
  for_each              = toset(local.private_dns_zones)
  name                  = "link-hub-${replace(each.value, ".", "-")}"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.this[each.value].name
  virtual_network_id    = azurerm_virtual_network.hub.id
  registration_enabled  = false
  resolution_policy     = "NxDomainRedirect"
  tags                  = var.tags
}

# ==============================================================================
# Azure Virtual Network Manager (AVNM)
# ==============================================================================

locals {
  avnm_management_group_id = "/providers/Microsoft.Management/managementGroups/${var.avnm_management_group_name}"
}

resource "azurerm_network_manager" "this" {
  count               = var.enable_avnm ? 1 : 0
  name                = "nm-${var.prefix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  scope_accesses      = ["Connectivity", "SecurityAdmin", "Routing"]
  tags                = var.tags

  scope {
    management_group_ids = [local.avnm_management_group_id]
  }
}

resource "azurerm_network_manager_management_group_connection" "this" {
  count               = var.enable_avnm ? 1 : 0
  name                = "nm-mg-${var.prefix}"
  network_manager_id  = azurerm_network_manager.this[0].id
  management_group_id = local.avnm_management_group_id
  description         = "Scope AVNM over landing zones management group"
}

resource "azurerm_network_manager_network_group" "hub" {
  count              = var.enable_avnm ? 1 : 0
  name               = "ng-${var.prefix}-hub"
  network_manager_id = azurerm_network_manager.this[0].id
  description        = "Hub VNet group"
}

resource "azurerm_network_manager_network_group" "spokes" {
  count              = var.enable_avnm ? 1 : 0
  name               = "ng-${var.prefix}-spokes"
  network_manager_id = azurerm_network_manager.this[0].id
  description        = "Spoke VNets group"
}

resource "azurerm_network_manager_static_member" "hub" {
  count                     = var.enable_avnm ? 1 : 0
  name                      = "member-${var.prefix}-hub"
  network_group_id          = azurerm_network_manager_network_group.hub[0].id
  target_virtual_network_id = azurerm_virtual_network.hub.id
}

resource "azurerm_network_manager_static_member" "spokes" {
  for_each                  = var.enable_avnm ? { for id in var.avnm_spoke_vnet_ids : id => id } : {}
  name                      = "member-${substr(md5(each.value), 0, 12)}"
  network_group_id          = azurerm_network_manager_network_group.spokes[0].id
  target_virtual_network_id = each.value
}

resource "azurerm_network_manager_connectivity_configuration" "hub_spoke" {
  count                 = var.enable_avnm ? 1 : 0
  name                  = "cc-${var.prefix}-hub-spoke"
  network_manager_id    = azurerm_network_manager.this[0].id
  connectivity_topology = "HubAndSpoke"

  hub {
    resource_id   = azurerm_virtual_network.hub.id
    resource_type = "Microsoft.Network/virtualNetworks"
  }

  applies_to_group {
    network_group_id   = azurerm_network_manager_network_group.spokes[0].id
    group_connectivity = "DirectlyConnected"
    use_hub_gateway    = false
  }
}

resource "azurerm_network_manager_security_admin_configuration" "alz" {
  count              = var.enable_avnm ? 1 : 0
  name               = "sac-${var.prefix}-alz"
  network_manager_id = azurerm_network_manager.this[0].id
  description        = "ALZ security admin guardrails"
}

resource "azurerm_network_manager_admin_rule_collection" "guardrails" {
  count                           = var.enable_avnm ? 1 : 0
  name                            = "arc-${var.prefix}-guardrails"
  security_admin_configuration_id = azurerm_network_manager_security_admin_configuration.alz[0].id
  network_group_ids               = [azurerm_network_manager_network_group.hub[0].id, azurerm_network_manager_network_group.spokes[0].id]
  description                     = "Global guardrail rules enforced before NSGs"
}

resource "azurerm_network_manager_admin_rule" "deny_rdp_inbound" {
  count                    = var.enable_avnm ? 1 : 0
  name                     = "deny-rdp-inbound"
  admin_rule_collection_id = azurerm_network_manager_admin_rule_collection.guardrails[0].id
  action                   = "Deny"
  direction                = "Inbound"
  priority                 = 100
  protocol                 = "Tcp"
  source_port_ranges       = ["*"]
  destination_port_ranges  = ["3389"]

  source {
    address_prefix_type = "IPPrefix"
    address_prefix      = "*"
  }

  destination {
    address_prefix_type = "IPPrefix"
    address_prefix      = "*"
  }
}

resource "azurerm_network_manager_admin_rule" "deny_ssh_inbound" {
  count                    = var.enable_avnm ? 1 : 0
  name                     = "deny-ssh-inbound"
  admin_rule_collection_id = azurerm_network_manager_admin_rule_collection.guardrails[0].id
  action                   = "Deny"
  direction                = "Inbound"
  priority                 = 110
  protocol                 = "Tcp"
  source_port_ranges       = ["*"]
  destination_port_ranges  = ["22"]

  source {
    address_prefix_type = "IPPrefix"
    address_prefix      = "*"
  }

  destination {
    address_prefix_type = "IPPrefix"
    address_prefix      = "*"
  }
}

resource "azurerm_network_manager_routing_configuration" "spokes" {
  count              = var.enable_avnm ? 1 : 0
  name               = "rc-${var.prefix}-spokes"
  network_manager_id = azurerm_network_manager.this[0].id
  description        = "Centralized UDRs for spokes"
}

resource "azurerm_network_manager_routing_rule_collection" "spokes" {
  count                         = var.enable_avnm ? 1 : 0
  name                          = "rrc-${var.prefix}-spokes"
  routing_configuration_id      = azurerm_network_manager_routing_configuration.spokes[0].id
  network_group_ids             = [azurerm_network_manager_network_group.spokes[0].id]
  bgp_route_propagation_enabled = false
}

resource "azurerm_network_manager_routing_rule" "default_to_firewall" {
  count              = var.enable_avnm ? 1 : 0
  name               = "route-default-to-firewall"
  rule_collection_id = azurerm_network_manager_routing_rule_collection.spokes[0].id
  description        = "Force all spoke egress traffic through hub firewall"

  destination {
    type    = "AddressPrefix"
    address = "0.0.0.0/0"
  }

  next_hop {
    type    = "VirtualAppliance"
    address = azurerm_firewall.this.ip_configuration[0].private_ip_address
  }
}

