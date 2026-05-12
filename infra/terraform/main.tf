# ==============================================================================
# Startup-Scale Landing Zone (SSLZ) — Terraform Root Module
# https://startupscalelanding.zone
# ==============================================================================
#
# NOTE: Management Groups
# -----------------------
# Management groups can now be deployed from this root module by setting:
#   enable_management_groups = true
#
# This still requires tenant-level permissions for azurerm_management_group
# resources. Keep it false if your principal does not have those permissions.
#
# See: ./modules/management-groups/main.tf
# ==============================================================================

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }

  # Remote backend for shared state. Required for CI/CD.
  # Run ./scripts/bootstrap-backend.sh -s <storage-account-name> to create the storage account.
  # For local dev without backend, run: terraform init -backend=false
  # Local interactive use should rely on Azure CLI auth. CI can enable workload identity
  # with: terraform init -backend-config="use_oidc=true" ...
  backend "azurerm" {
    resource_group_name  = "rg-terraform-state"
    storage_account_name = "tfstate20250511"
    container_name       = "tfstate"
    key                  = "landing-zone.tfstate"
  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = true
    }
    key_vault {
      purge_soft_delete_on_destroy    = false
      recover_soft_deleted_key_vaults = true
    }
  }
}

provider "azurerm" {
  alias = "networking"
  features {
    resource_group {
      prevent_deletion_if_contains_resources = true
    }
    key_vault {
      purge_soft_delete_on_destroy    = false
      recover_soft_deleted_key_vaults = true
    }
  }
  subscription_id = var.networking_subscription_id
}

provider "azurerm" {
  alias = "management"
  features {
    resource_group {
      prevent_deletion_if_contains_resources = true
    }
    key_vault {
      purge_soft_delete_on_destroy    = false
      recover_soft_deleted_key_vaults = true
    }
  }
  subscription_id = var.management_subscription_id
}

provider "azurerm" {
  alias = "prod"
  features {
    resource_group {
      prevent_deletion_if_contains_resources = true
    }
    key_vault {
      purge_soft_delete_on_destroy    = false
      recover_soft_deleted_key_vaults = true
    }
  }
  subscription_id = var.prod_subscription_id
}

provider "azurerm" {
  alias = "devtest"
  features {
    resource_group {
      prevent_deletion_if_contains_resources = true
    }
    key_vault {
      purge_soft_delete_on_destroy    = false
      recover_soft_deleted_key_vaults = true
    }
  }
  subscription_id = var.devtest_subscription_id
}

check "separate_networking_and_management_subscriptions" {
  assert {
    condition = (
      var.networking_subscription_id == "" ||
      var.management_subscription_id == "" ||
      var.networking_subscription_id != var.management_subscription_id
    )
    error_message = "networking_subscription_id and management_subscription_id must be different when both are set."
  }
}

check "management_groups_requires_subscription_context" {
  assert {
    condition = (
      !var.enable_management_groups ||
      var.management_subscription_id != "" ||
      var.networking_subscription_id != ""
    )
    error_message = "enable_management_groups=true requires at least one subscription context (management_subscription_id or networking_subscription_id)."
  }
}

# ==============================================================================
# Resource Groups
# ==============================================================================

resource "azurerm_resource_group" "monitoring" {
  count    = var.management_subscription_id != "" ? 1 : 0
  provider = azurerm.management
  name     = "rg-${local.prefix}-monitoring"
  location = var.location
  tags     = local.tags
}

resource "azurerm_resource_group" "networking" {
  count    = var.networking_subscription_id != "" ? 1 : 0
  provider = azurerm.networking
  name     = "rg-${local.prefix}-networking"
  location = var.location
  tags     = local.tags
}

# ==============================================================================
# Modules
# ==============================================================================

module "management_groups" {
  count  = var.enable_management_groups ? 1 : 0
  source = "./modules/management-groups"

  subscription_id         = var.management_subscription_id != "" ? var.management_subscription_id : var.networking_subscription_id
  company_name            = var.company_name
  display_name            = var.management_group_display_name
  prod_subscription_id    = var.prod_subscription_id
  nonprod_subscription_id = var.devtest_subscription_id
}

module "log_analytics" {
  count = var.management_subscription_id != "" ? 1 : 0
  providers = {
    azurerm = azurerm.management
  }
  source              = "./modules/monitoring"
  location            = var.location
  resource_group_name = azurerm_resource_group.monitoring[0].name
  workspace_name      = "law-${local.prefix}"
  retention_in_days   = var.log_retention_in_days
  daily_quota_gb      = var.log_daily_quota_gb
  tags                = local.tags
}

module "networking" {
  count = var.networking_subscription_id != "" ? 1 : 0
  providers = {
    azurerm = azurerm.networking
  }
  source                     = "./modules/networking"
  location                   = var.location
  resource_group_name        = azurerm_resource_group.networking[0].name
  prefix                     = local.prefix
  hub_address_space          = var.hub_address_space != "" ? var.hub_address_space : "10.0.0.0/16"
  app_subnet_delegation      = var.app_subnet_delegation
  tags                       = local.tags

  depends_on = [
    module.management_groups
  ]
}

# NOTE: Security Center pricing resources must be imported if managed via Terraform.
# See modules/security/README.md for import instructions.

module "security" {
  count = var.management_subscription_id != "" ? 1 : 0
  providers = {
    azurerm = azurerm.management
  }
  source                         = "./modules/security"
  security_contact_email         = var.security_contact_email
  enable_defender_for_servers    = local.enable_defender_for_servers
  enable_defender_for_containers = var.enable_defender_for_containers
  enable_defender_for_databases  = local.enable_defender_for_databases
  enable_defender_for_key_vault  = var.enable_defender_for_key_vault
}

module "policy" {
  count = var.management_subscription_id != "" ? 1 : 0
  providers = {
    azurerm = azurerm.management
  }
  source                     = "./modules/policy"
  location                   = var.location
  allowed_locations          = local.allowed_locations
  log_analytics_workspace_id = module.log_analytics[0].workspace_id
  management_group_name      = var.policy_management_group_name
  landing_zone_subscription_ids = compact([
    var.prod_subscription_id,
    var.devtest_subscription_id,
  ])
}

# ==============================================================================
# Activity Log — Diagnostic Setting (immediate, not waiting for DINE policy)
# ==============================================================================

resource "azurerm_monitor_diagnostic_setting" "activity_log" {
  count                      = var.management_subscription_id != "" ? 1 : 0
  provider                   = azurerm.management
  name                       = "diag-activity-log-to-law"
  target_resource_id         = "/subscriptions/${var.management_subscription_id}"
  log_analytics_workspace_id = module.log_analytics[0].workspace_id

  enabled_log {
    category = "Administrative"
  }
  enabled_log {
    category = "Security"
  }
  enabled_log {
    category = "Alert"
  }
  enabled_log {
    category = "Policy"
  }
  enabled_log {
    category = "ServiceHealth"
  }
  enabled_log {
    category = "Recommendation"
  }
  enabled_log {
    category = "Autoscale"
  }
  enabled_log {
    category = "ResourceHealth"
  }
}

# ==============================================================================
# Budget
# For cost anomaly detection, enable it in the Azure Portal:
# Cost Management → Cost alerts → Anomaly alerts (no Terraform resource available).
# See docs/cost-management.md for details.
# ==============================================================================

resource "azurerm_consumption_budget_subscription" "monthly" {
  count           = var.management_subscription_id != "" ? 1 : 0
  provider        = azurerm.management
  name            = "budget-${local.prefix}-monthly"
  subscription_id = "/subscriptions/${var.management_subscription_id}"
  amount          = var.monthly_budget_amount
  time_grain      = "Monthly"

  time_period {
    start_date = local.budget_start_date
  }

  lifecycle {
    ignore_changes = [time_period]
  }

  notification {
    enabled        = true
    threshold      = 50
    operator       = "GreaterThan"
    threshold_type = "Actual"
    contact_emails = var.budget_alert_emails
  }

  notification {
    enabled        = true
    threshold      = 80
    operator       = "GreaterThan"
    threshold_type = "Actual"
    contact_emails = var.budget_alert_emails
  }

  notification {
    enabled        = true
    threshold      = 100
    operator       = "GreaterThan"
    threshold_type = "Actual"
    contact_emails = var.budget_alert_emails
  }

  notification {
    enabled        = true
    threshold      = 100
    operator       = "GreaterThan"
    threshold_type = "Forecasted"
    contact_emails = var.budget_alert_emails
  }

}
