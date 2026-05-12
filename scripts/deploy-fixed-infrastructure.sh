#!/bin/bash
# ============================================================================
# Azure Landing Zone — Complete Deployment Fix & Execution Script
# ============================================================================
# This script executes all steps to fix and deploy the ALZ infrastructure
# Usage: bash deploy-fixed-infrastructure.sh [subscription-id]
# ============================================================================

set -euo pipefail

# Configuration
SUBSCRIPTION_ID=\"${1:-71fc303d-592a-4360-8147-39b1daf37558}\"
PROJECT_ROOT=\"$(cd \"$(dirname \"${BASH_SOURCE[0]}\")\" && pwd)\"
TF_DIR=\"$PROJECT_ROOT/infra/terraform\"
SCRIPT_DIR=\"$PROJECT_ROOT/scripts\"

# Colors for output
RED='\\033[0;31m'
GREEN='\\033[0;32m'
YELLOW='\\033[1;33m'
BLUE='\\033[0;34m'
NC='\\033[0m' # No Color

log_info() { echo -e \"${BLUE}[INFO]${NC} $1\"; }
log_success() { echo -e \"${GREEN}[SUCCESS]${NC} $1\"; }
log_warning() { echo -e \"${YELLOW}[WARNING]${NC} $1\"; }
log_error() { echo -e \"${RED}[ERROR]${NC} $1\"; }

# ============================================================================
# PRE-DEPLOYMENT CHECKS
# ============================================================================

echo \"\"
echo \"=================================\"
echo \"ALZ Terraform - Deployment Script\"
echo \"=================================\"
echo \"\"

log_info \"Checking prerequisites...\"
log_info \"Subscription ID: $SUBSCRIPTION_ID\"
log_info \"Project Root: $PROJECT_ROOT\"
log_info \"Terraform Dir: $TF_DIR\"
echo \"\"

# Check if terraform is installed
if ! command -v terraform &> /dev/null; then
    log_error \"Terraform not found. Please install Terraform v1.5.0 or later.\"
    exit 1
fi
log_success \"Terraform found: $(terraform version -json | jq -r '.terraform_version')\"

# Check if az cli is installed
if ! command -v az &> /dev/null; then
    log_error \"Azure CLI not found. Please install Azure CLI.\"
    exit 1
fi
log_success \"Azure CLI found: $(az version -o json | jq -r '.\\\"azure-cli\\\"')\"

# Check directories
if [ ! -d \"$TF_DIR\" ]; then
    log_error \"Terraform directory not found: $TF_DIR\"
    exit 1
fi
log_success \"Terraform directory found\"

if [ ! -f \"$TF_DIR/terraform.tfvars\" ]; then
    log_warning \"terraform.tfvars not found. Using defaults.\"
fi
log_success \"All prerequisites met\"
echo \"\"

# ============================================================================
# STEP 1: INITIALIZE & DEPLOY NETWORKING + POLICIES
# ============================================================================

echo \"\"
echo \"=================================\"
echo \"STEP 1: Deploy Networking & Policies\"
echo \"=================================\"
echo \"\"

log_info \"Changing to Terraform directory...\"
cd \"$TF_DIR\"

log_info \"Running terraform init...\"
terraform init -upgrade

log_info \"Running terraform plan for networking & policy modules...\"
terraform plan \\
  -target=module.log_analytics \\
  -target=module.networking \\
  -target=module.policy \\
  -out=tfplan.step1

log_info \"Applying networking & policy modules...\"
log_warning \"Review the plan above. Press Enter to continue or Ctrl+C to abort.\"
read -p \"\"

terraform apply tfplan.step1

log_success \"Networking & policy modules deployed successfully\"
echo \"\"

# ============================================================================
# STEP 2: IMPORT SECURITY CENTER PRICING RESOURCES
# ============================================================================

echo \"\"
echo \"=================================\"
echo \"STEP 2: Import Security Pricing Resources\"
echo \"=================================\"
echo \"\"

log_info \"Starting import of Security Center pricing resources...\"
log_info \"Subscription: $SUBSCRIPTION_ID\"
echo \"\"

# Define pricing resources
declare -a PRICING_TYPES=(
    \"CloudPosture:cspm\"
    \"VirtualMachines:servers\"
    \"Containers:containers\"
    \"SqlServers:sql\"
    \"OpenSourceRelationalDatabases:oss_db\"
    \"KeyVaults:keyvault\"
    \"Arm:arm\"
    \"StorageAccounts:storage\"
)

IMPORT_SUCCESS=0
IMPORT_FAILED=0

for pair in \"${PRICING_TYPES[@]}\"; do
    IFS=':' read -r PRICING_TYPE RESOURCE_NAME <<< \"$pair\"
    RESOURCE_ID=\"/subscriptions/$SUBSCRIPTION_ID/providers/Microsoft.Security/pricings/$PRICING_TYPE\"
    
    log_info \"Importing $PRICING_TYPE...\"
    
    if terraform import \"module.security[0].azurerm_security_center_subscription_pricing.$RESOURCE_NAME\" \"$RESOURCE_ID\" 2>&1; then
        log_success \"Imported $PRICING_TYPE\"
        ((IMPORT_SUCCESS++))
    else
        log_error \"Failed to import $PRICING_TYPE\"
        ((IMPORT_FAILED++))
    fi
done

echo \"\"
echo \"Import Summary: $IMPORT_SUCCESS succeeded, $IMPORT_FAILED failed\"

if [ $IMPORT_FAILED -gt 0 ]; then
    log_warning \"Some imports failed. This may be OK if resources don't exist yet.\"
    log_info \"Continuing with deployment...\"
fi

echo \"\"

# ============================================================================
# STEP 3: DEPLOY SECURITY MODULE
# ============================================================================

echo \"\"
echo \"=================================\"
echo \"STEP 3: Deploy Security Module\"
echo \"=================================\"
echo \"\"

log_info \"Planning full infrastructure deployment (including security module)...\"
terraform plan -out=tfplan.step3

log_info \"Applying full infrastructure...\"
log_warning \"Review the plan above. Press Enter to continue or Ctrl+C to abort.\"
read -p \"\"

terraform apply tfplan.step3

log_success \"Full infrastructure deployed successfully\"
echo \"\"

# ============================================================================
# POST-DEPLOYMENT VALIDATION
# ============================================================================

echo \"\"
echo \"=================================\"
echo \"POST-DEPLOYMENT VALIDATION\"
echo \"=================================\"
echo \"\"

log_info \"Checking deployed resources...\"

# Check resource groups
log_info \"Checking resource groups...\"
RG_COUNT=$(terraform state list | grep -c 'azurerm_resource_group' || echo 0)
log_success \"Found $RG_COUNT resource groups\"

# Check virtual networks
log_info \"Checking virtual networks...\"
VNET_COUNT=$(terraform state list | grep -c 'azurerm_virtual_network' || echo 0)
log_success \"Found $VNET_COUNT virtual networks\"

# Check subnets
log_info \"Checking subnets...\"
SUBNET_COUNT=$(terraform state list | grep -c 'azurerm_subnet' || echo 0)
log_success \"Found $SUBNET_COUNT subnets\"

# Check private DNS zones
log_info \"Checking private DNS zones...\"
DNS_ZONE_COUNT=$(terraform state list | grep -c 'azurerm_private_dns_zone.this' || echo 0)
log_success \"Found $DNS_ZONE_COUNT private DNS zones\"

# Check firewall
log_info \"Checking Azure Firewall...\"
if terraform state list | grep -q 'azurerm_firewall.this'; then
    log_success \"Azure Firewall deployed\"
else
    log_warning \"Azure Firewall not found in state\"
fi

# Check pricing resources
log_info \"Checking Security Center pricing resources...\"
PRICING_COUNT=$(terraform state list | grep -c 'azurerm_security_center_subscription_pricing' || echo 0)
log_success \"Found $PRICING_COUNT pricing resources imported\"

echo \"\"

# ============================================================================
# SUMMARY & NEXT STEPS
# ============================================================================

echo \"\"
echo \"=================================\"
echo \"✅ DEPLOYMENT COMPLETE\"
echo \"=================================\"
echo \"\"

log_success \"Your Azure Landing Zone infrastructure is now deployed!\"
echo \"\"

echo \"Summary:\"
echo \"  • Resource Groups: $RG_COUNT\"
echo \"  • Virtual Networks: $VNET_COUNT\"
echo \"  • Subnets: $SUBNET_COUNT\"
echo \"  • Private DNS Zones: $DNS_ZONE_COUNT\"
echo \"  • Security Pricing Resources: $PRICING_COUNT\"
echo \"\"

echo \"Next Steps:\"
echo \"  1. Review your resources in the Azure Portal\"
echo \"  2. Run post-deployment validation: see DEPLOYMENT_CHECKLIST.md\"
echo \"  3. Deploy workloads to prod/nonprod spokes\"
echo \"  4. Configure network security and policies\"
echo \"\"

echo \"Documentation:\"
echo \"  • Detailed Fix Guide: $PROJECT_ROOT/TERRAFORM_FIX_GUIDE.md\"
echo \"  • Deployment Summary: $PROJECT_ROOT/DEPLOYMENT_FIX_SUMMARY.md\"
echo \"  • Architecture Docs: $PROJECT_ROOT/ARCHITECTURE.md\"
echo \"\"

log_success \"Deployment script completed successfully!\"
echo \"\"
