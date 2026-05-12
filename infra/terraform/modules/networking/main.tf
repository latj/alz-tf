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
    "privatelink.azconfig.io",
    "privatelink.azure-api.net",
    format("privatelink.%s.azurecontainerapps.io", var.location),
    "privatelink.azurecr.io",
    "privatelink.blob.core.windows.net",
    "privatelink.documents.azure.com",
    "privatelink.search.windows.net",
    "privatelink.vaultcore.azure.net",
    "privatelink.services.ai.azure.com",
    "privatelink.cognitiveservices.azure.com",
    "privatelink.openai.azure.com"
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

