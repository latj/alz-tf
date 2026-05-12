# ==============================================================================
# Management Groups
# Deploy as a standalone root module: terraform apply -var='...'
# Requires tenant-level permissions
# ==============================================================================

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

locals {
  display_name = var.display_name != "" ? var.display_name : "${var.company_name} Landing Zone"
}

# Root Management Group
resource "azurerm_management_group" "root" {
  name         = "mg-${var.company_name}"
  display_name = local.display_name
}

# Platform Management Group (for shared services)
resource "azurerm_management_group" "platform" {
  name                       = "mg-${var.company_name}-platform"
  display_name               = "${var.company_name} Platform"
  parent_management_group_id = azurerm_management_group.root.id
}

# Landing Zones Management Group
resource "azurerm_management_group" "landing_zones" {
  name                       = "mg-${var.company_name}-landing-zones"
  display_name               = "${var.company_name} Landing Zones"
  parent_management_group_id = azurerm_management_group.root.id
}

# Production Landing Zone
resource "azurerm_management_group" "prod" {
  name                       = "mg-${var.company_name}-prod"
  display_name               = "${var.company_name} Production"
  parent_management_group_id = azurerm_management_group.landing_zones.id

  subscription_ids = var.prod_subscription_id != "" ? [var.prod_subscription_id] : []
}

# Non-Production Landing Zone
resource "azurerm_management_group" "nonprod" {
  name                       = "mg-${var.company_name}-nonprod"
  display_name               = "${var.company_name} Non-Production"
  parent_management_group_id = azurerm_management_group.landing_zones.id

  subscription_ids = var.nonprod_subscription_id != "" ? [var.nonprod_subscription_id] : []
}
