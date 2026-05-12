# ==============================================================================
# Azure Landing Zone - Terraform Variables Example
# ==============================================================================
# Copy this file to terraform.tfvars and customize for your environment
# ==============================================================================

# ==============================================================================
# Subscription Configuration - Multi-Subscription Deployment
# ==============================================================================
# Each component deploys to its own subscription for better separation of concerns
# LEAVE SUBSCRIPTION IDs EMPTY to skip deployment of that component
#
# 1. Networking/Connectivity Subscription:
#    - Hub VNet, Azure Firewall, Private DNS Resolver, VNets, Subnets
#    - Resource Group: rg-{company}-{env}-networking
#    - Leave empty to skip networking deployment
#
# 2. Management Subscription:
#    - Log Analytics Workspace, Azure Policies, Defender for Cloud
#    - Resource Group: rg-{company}-{env}-monitoring
#    - Leave empty to skip management deployment
#
# 3. Production Landing Zone Subscription:
#    - Reserved for production workloads (VMs, AKS, databases, etc.)
#    - No resources deployed by this Terraform config
#    - Leave empty if not using separate prod subscription
#
# 4. DevTest Landing Zone Subscription:
#    - Reserved for dev/test workloads
#    - No resources deployed by this Terraform config
#    - Leave empty if not using separate devtest subscription

# Networking/Connectivity Subscription - Hub VNet, Firewall, DNS, VNets (leave empty to skip)
networking_subscription_id = "d406302e-6d92-45a6-9764-d8cf8915deb9"

# Management Subscription - Monitoring, Policies, Security (Defender) (leave empty to skip)
management_subscription_id = "71fc303d-592a-4360-8147-39b1daf37558"

# Production Landing Zone Subscription - For prod workloads (leave empty to skip)
prod_subscription_id = ""

# DevTest Landing Zone Subscription - For dev/test workloads (leave empty to skip)
devtest_subscription_id = ""


# Management groups (tenant-level permissions required)
enable_management_groups = true
# Optional root management group display name
# management_group_display_name = "acme Landing Zone"

# Azure policy assignment scope (management group)
policy_management_group_name = "mg-acme-landing-zones"

# ==============================================================================
# Azure Configuration
# ==============================================================================
location = "swedencentral"

# ==============================================================================
# Company and Environment
# ==============================================================================
company_name = "acme" # Used in all resource naming (2-20 chars, lowercase alphanumeric)
environment  = "prod" # Options: prod, nonprod

# ==============================================================================
# Networking - Hub-Spoke Architecture
# ==============================================================================

# Hub VNet Address Space (central region)
hub_address_space = "10.32.96.0/23"

# Enable VPN Gateway deployment (for site-to-site connectivity)
enable_vpn_gateway = false

# ==============================================================================
# Monitoring and Logging
# ==============================================================================

log_retention_in_days = 90 # Range: 30-730 days
log_daily_quota_gb    = 5  # Daily ingestion quota (-1 = unlimited)

# ==============================================================================
# Security and Compliance
# ==============================================================================

security_contact_email = "anjansso@microsoft.com"

# Defender for Cloud Settings
enable_defender_for_servers    = true
enable_defender_for_containers = true
enable_defender_for_databases  = true
enable_defender_for_key_vault  = true

# ==============================================================================
# Resource Tagging
# ==============================================================================

tags = {
  environment = "prod"
  team        = "platform"
  CostCenter  = "Engineering"
  ManagedBy   = "Terraform"
}
# budget_start_date = "2026-03-01T00:00:00Z"

# VNet address space — leave empty to use defaults (prod: 10.0.0.0/16, nonprod: 10.1.0.0/16)
# vnet_address_prefix = "10.0.0.0/16"

# Service delegation for the app subnet.
# Use "Microsoft.Web/serverFarms" for App Service or "Microsoft.App/environments" for Container Apps.
# Default: "Microsoft.Web/serverFarms"
# app_subnet_delegation = "Microsoft.App/environments"

# Defender for Cloud plans — enable what you need
# Servers and Databases default to null (auto-enabled for prod, disabled for nonprod).
# Key Vault defaults to true (low cost, always worth enabling).
# enable_defender_for_servers    = true  # recommended for prod (~$15/server/month)
# enable_defender_for_containers = false # set true if running AKS (~$7/vCPU/month)
# enable_defender_for_databases  = true  # recommended for prod (~$15/server/month)
# enable_defender_for_key_vault = true  # default: true, low cost (~$0.02/10K transactions)

# Restrict deployments to these Azure regions (defaults to [location] if omitted)
# allowed_locations = ["eastus2", "centralus"]

# Additional tags merged with defaults (environment, managedBy, project, team)
# tags = {
#   costCenter = "engineering"
# }
