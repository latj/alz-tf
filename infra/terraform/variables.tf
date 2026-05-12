variable "networking_subscription_id" {
  description = "Azure subscription ID for Networking/Connectivity resources (leave empty to skip networking deployment)"
  type        = string
  default     = ""
  validation {
    condition     = var.networking_subscription_id == "" || can(regex("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", var.networking_subscription_id))
    error_message = "networking_subscription_id must be empty or a valid UUID."
  }
}

variable "management_subscription_id" {
  description = "Azure subscription ID for Management resources (monitoring, policy, security) (leave empty to skip management deployment)"
  type        = string
  default     = ""
  validation {
    condition     = var.management_subscription_id == "" || can(regex("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", var.management_subscription_id))
    error_message = "management_subscription_id must be empty or a valid UUID."
  }
}

variable "prod_subscription_id" {
  description = "Azure subscription ID for Production Landing Zone (leave empty to skip production setup)"
  type        = string
  default     = ""
  validation {
    condition     = var.prod_subscription_id == "" || can(regex("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", var.prod_subscription_id))
    error_message = "prod_subscription_id must be empty or a valid UUID."
  }
}

variable "devtest_subscription_id" {
  description = "Azure subscription ID for DevTest Landing Zone (leave empty to skip devtest setup)"
  type        = string
  default     = ""
  validation {
    condition     = var.devtest_subscription_id == "" || can(regex("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", var.devtest_subscription_id))
    error_message = "devtest_subscription_id must be empty or a valid UUID."
  }
}

variable "enable_management_groups" {
  description = "Enable management group hierarchy deployment from the root module (requires tenant-level permissions)."
  type        = bool
  default     = false
}

variable "management_group_display_name" {
  description = "Optional display name for the root management group (defaults to '<company_name> Landing Zone')."
  type        = string
  default     = ""
}

variable "policy_management_group_name" {
  description = "Management group name to scope policy assignments (e.g., mg-acme-landing-zones)."
  type        = string
  default     = "mg-acme-landing-zones"
}

variable "enable_avnm" {
  description = "Enable Azure Virtual Network Manager in networking subscription."
  type        = bool
  default     = false
}

variable "avnm_management_group_name" {
  description = "Management group name to scope AVNM configurations (e.g., mg-acme-landing-zones)."
  type        = string
  default     = "mg-acme-landing-zones"
}

variable "avnm_spoke_vnet_ids" {
  description = "List of spoke VNet resource IDs for AVNM hub-spoke and routing configurations."
  type        = list(string)
  default     = []
}

variable "location" {
  description = "Primary Azure region"
  type        = string
  default     = "swedencentral"
  validation {
    condition     = can(regex("^[a-z]+[a-z0-9]*$", var.location))
    error_message = "location must be a valid Azure region name (e.g., eastus2, westeurope)."
  }
}

variable "company_name" {
  description = "Company name used in resource naming (2-20 lowercase alphanumeric characters)"
  type        = string
  validation {
    condition     = can(regex("^[a-z][a-z0-9]{1,19}$", var.company_name))
    error_message = "company_name must be 2-20 lowercase alphanumeric characters, starting with a letter."
  }
}

variable "environment" {
  description = "Environment: prod or nonprod"
  type        = string
  validation {
    condition     = contains(["prod", "nonprod"], var.environment)
    error_message = "Environment must be 'prod' or 'nonprod'."
  }
}

variable "prefix" {
  description = "Resource naming prefix (defaults to company_name-environment)"
  type        = string
  default     = ""
}

variable "log_retention_in_days" {
  description = "Log Analytics workspace retention in days"
  type        = number
  default     = 90
  validation {
    condition     = var.log_retention_in_days >= 30 && var.log_retention_in_days <= 730
    error_message = "log_retention_in_days must be between 30 and 730."
  }
}

variable "log_daily_quota_gb" {
  description = "Log Analytics daily ingestion quota in GB (-1 = unlimited)"
  type        = number
  default     = 5
}

variable "hub_address_space" {
  description = "Hub VNet address space (e.g., 10.0.0.0/16)"
  type        = string
  default     = ""
  validation {
    condition     = var.hub_address_space == "" || can(cidrhost(var.hub_address_space, 0))
    error_message = "hub_address_space must be a valid CIDR block (e.g., 10.0.0.0/16) or empty for the default."
  }
}

variable "app_subnet_delegation" {
  description = "Service delegation for the app subnet (e.g., Microsoft.Web/serverFarms for App Service, Microsoft.App/environments for Container Apps)"
  type        = string
  default     = "Microsoft.Web/serverFarms"
}

variable "enable_vpn_gateway" {
  description = "Enable deployment of Azure VPN Gateway in the hub VNet for site-to-site connectivity"
  type        = bool
  default     = false
}

variable "monthly_budget_amount" {
  description = "Monthly budget amount in USD"
  type        = number
  default     = 5000
}

variable "budget_alert_emails" {
  description = "Email addresses for budget alerts"
  type        = list(string)
  default     = ["platform@example.com"]
  validation {
    condition     = length(var.budget_alert_emails) > 0
    error_message = "budget_alert_emails must contain at least one email address."
  }
}

variable "budget_start_date" {
  description = "Budget start date in ISO 8601 format (e.g., 2026-03-01T00:00:00Z). Must be the first of a month. Defaults to the 1st of the current month."
  type        = string
  default     = ""
  validation {
    condition     = var.budget_start_date == "" || can(regex("^\\d{4}-\\d{2}-01T00:00:00Z$", var.budget_start_date))
    error_message = "budget_start_date must be the first of a month in ISO 8601 format (e.g., 2026-03-01T00:00:00Z)."
  }
}

variable "security_contact_email" {
  description = "Email address for Defender for Cloud security alerts"
  type        = string
  default     = "security@example.com"
  validation {
    condition     = can(regex("^[^@]+@[^@]+\\.[^@]+$", var.security_contact_email))
    error_message = "security_contact_email must be a valid email address."
  }
}

variable "enable_defender_for_servers" {
  description = "Enable Defender for Servers P2 (recommended for prod)"
  type        = bool
  default     = null
}

variable "enable_defender_for_containers" {
  description = "Enable Defender for Containers (recommended if running AKS)"
  type        = bool
  default     = false
}

variable "enable_defender_for_databases" {
  description = "Enable Defender for Databases (recommended for prod)"
  type        = bool
  default     = null
}

variable "enable_defender_for_key_vault" {
  description = "Enable Defender for Key Vault (recommended, low cost)"
  type        = bool
  default     = true
}

variable "allowed_locations" {
  description = "Allowed Azure regions for resource deployment (defaults to the primary location)"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags applied to all resources"
  type        = map(string)
  default     = {}
}

locals {
  prefix = var.prefix != "" ? var.prefix : "${var.company_name}-${var.environment}"

  # Defender defaults: enable Servers and Databases for prod (matches Bicep behavior)
  enable_defender_for_servers   = var.enable_defender_for_servers != null ? var.enable_defender_for_servers : var.environment == "prod"
  enable_defender_for_databases = var.enable_defender_for_databases != null ? var.enable_defender_for_databases : var.environment == "prod"

  budget_start_date = var.budget_start_date != "" ? var.budget_start_date : formatdate("YYYY-MM-01'T'00:00:00Z", plantimestamp())

  # Allowed locations: defaults to [var.location] to match Bicep's [location] behavior
  allowed_locations = length(var.allowed_locations) > 0 ? var.allowed_locations : [var.location]

  default_tags = {
    environment = var.environment
    ManagedBy   = "terraform"
    project     = "landing-zone"
    team        = "platform"
  }

  tags = merge(local.default_tags, var.tags)
}
