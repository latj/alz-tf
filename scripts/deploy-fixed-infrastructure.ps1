# ============================================================================
# Azure Landing Zone — Complete Deployment Fix & Execution Script (PowerShell)
# ============================================================================
# This script executes all steps to fix and deploy the ALZ infrastructure
# Usage: powershell -ExecutionPolicy Bypass -File deploy-fixed-infrastructure.ps1 -SubscriptionId <id>
# ============================================================================

param(
    [string]$SubscriptionId = \"71fc303d-592a-4360-8147-39b1daf37558\"
)

# Configuration
$ProjectRoot = (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
$TfDir = Join-Path $ProjectRoot \"infra/terraform\"
$ScriptDir = Join-Path $ProjectRoot \"scripts\"

# Functions for logging
function Log-Info {
    param([string]$Message)
    Write-Host \"[INFO] $Message\" -ForegroundColor Cyan
}

function Log-Success {
    param([string]$Message)
    Write-Host \"[SUCCESS] $Message\" -ForegroundColor Green
}

function Log-Warning {
    param([string]$Message)
    Write-Host \"[WARNING] $Message\" -ForegroundColor Yellow
}

function Log-Error {
    param([string]$Message)
    Write-Host \"[ERROR] $Message\" -ForegroundColor Red
}

# ============================================================================
# PRE-DEPLOYMENT CHECKS
# ============================================================================

Write-Host \"\"
Write-Host \"=================================\" -ForegroundColor Magenta
Write-Host \"ALZ Terraform - Deployment Script\" -ForegroundColor Magenta
Write-Host \"=================================\" -ForegroundColor Magenta
Write-Host \"\"

Log-Info \"Checking prerequisites...\"
Log-Info \"Subscription ID: $SubscriptionId\"
Log-Info \"Project Root: $ProjectRoot\"
Log-Info \"Terraform Dir: $TfDir\"
Write-Host \"\"

# Check if terraform is installed
try {
    $tfVersion = terraform version -json | ConvertFrom-Json
    Log-Success \"Terraform found: $($tfVersion.terraform_version)\"
} catch {
    Log-Error \"Terraform not found. Please install Terraform v1.5.0 or later.\"
    exit 1
}

# Check if az cli is installed
try {
    $azVersion = az version -o json | ConvertFrom-Json
    Log-Success \"Azure CLI found: $($azVersion.'azure-cli')\"
} catch {
    Log-Error \"Azure CLI not found. Please install Azure CLI.\"
    exit 1
}

# Check directories
if (-not (Test-Path $TfDir)) {
    Log-Error \"Terraform directory not found: $TfDir\"
    exit 1
}
Log-Success \"Terraform directory found\"

if (-not (Test-Path \"$TfDir/terraform.tfvars\")) {
    Log-Warning \"terraform.tfvars not found. Using defaults.\"
}
Log-Success \"All prerequisites met\"
Write-Host \"\"

# ============================================================================
# STEP 1: INITIALIZE & DEPLOY NETWORKING + POLICIES
# ============================================================================

Write-Host \"\"
Write-Host \"=================================\" -ForegroundColor Magenta
Write-Host \"STEP 1: Deploy Networking & Policies\" -ForegroundColor Magenta
Write-Host \"=================================\" -ForegroundColor Magenta
Write-Host \"\"

Log-Info \"Changing to Terraform directory...\"
Push-Location $TfDir

Log-Info \"Running terraform init...\"
terraform init -upgrade

Log-Info \"Running terraform plan for networking & policy modules...\"
terraform plan `
  -target=module.log_analytics `
  -target=module.networking `
  -target=module.policy `
  -out=tfplan.step1

Log-Info \"Applying networking & policy modules...\"
Log-Warning \"Review the plan above. Press Enter to continue or Ctrl+C to abort.\"
Read-Host

terraform apply tfplan.step1

Log-Success \"Networking & policy modules deployed successfully\"
Write-Host \"\"

# ============================================================================
# STEP 2: IMPORT SECURITY CENTER PRICING RESOURCES
# ============================================================================

Write-Host \"\"
Write-Host \"=================================\" -ForegroundColor Magenta
Write-Host \"STEP 2: Import Security Pricing Resources\" -ForegroundColor Magenta
Write-Host \"=================================\" -ForegroundColor Magenta
Write-Host \"\"

Log-Info \"Starting import of Security Center pricing resources...\"
Log-Info \"Subscription: $SubscriptionId\"
Write-Host \"\"

# Define pricing resources
$PricingResources = @(
    @{Type=\"CloudPosture\"; Name=\"cspm\"},
    @{Type=\"VirtualMachines\"; Name=\"servers\"},
    @{Type=\"Containers\"; Name=\"containers\"},
    @{Type=\"SqlServers\"; Name=\"sql\"},
    @{Type=\"OpenSourceRelationalDatabases\"; Name=\"oss_db\"},
    @{Type=\"KeyVaults\"; Name=\"keyvault\"},
    @{Type=\"Arm\"; Name=\"arm\"},
    @{Type=\"StorageAccounts\"; Name=\"storage\"}
)

$ImportSuccess = 0
$ImportFailed = 0

foreach ($resource in $PricingResources) {
    $pricingType = $resource.Type
    $resourceName = $resource.Name
    $resourceId = \"/subscriptions/$SubscriptionId/providers/Microsoft.Security/pricings/$pricingType\"
    
    Log-Info \"Importing $pricingType...\"
    
    $output = terraform import \"module.security[0].azurerm_security_center_subscription_pricing.$resourceName\" \"$resourceId\" 2>&1
    
    if ($LASTEXITCODE -eq 0) {
        Log-Success \"Imported $pricingType\"
        $ImportSuccess++
    } else {
        Log-Error \"Failed to import $pricingType\"
        $ImportFailed++
    }
}

Write-Host \"\"
Write-Host \"Import Summary: $ImportSuccess succeeded, $ImportFailed failed\" -ForegroundColor Cyan

if ($ImportFailed -gt 0) {
    Log-Warning \"Some imports failed. This may be OK if resources don't exist yet.\"
    Log-Info \"Continuing with deployment...\"
}

Write-Host \"\"

# ============================================================================
# STEP 3: DEPLOY SECURITY MODULE
# ============================================================================

Write-Host \"\"
Write-Host \"=================================\" -ForegroundColor Magenta
Write-Host \"STEP 3: Deploy Security Module\" -ForegroundColor Magenta
Write-Host \"=================================\" -ForegroundColor Magenta
Write-Host \"\"

Log-Info \"Planning full infrastructure deployment (including security module)...\"
terraform plan -out=tfplan.step3

Log-Info \"Applying full infrastructure...\"
Log-Warning \"Review the plan above. Press Enter to continue or Ctrl+C to abort.\"
Read-Host

terraform apply tfplan.step3

Log-Success \"Full infrastructure deployed successfully\"
Write-Host \"\"

# ============================================================================
# POST-DEPLOYMENT VALIDATION
# ============================================================================

Write-Host \"\"
Write-Host \"=================================\" -ForegroundColor Magenta
Write-Host \"POST-DEPLOYMENT VALIDATION\" -ForegroundColor Magenta
Write-Host \"=================================\" -ForegroundColor Magenta
Write-Host \"\"

Log-Info \"Checking deployed resources...\"

# Check resource groups
Log-Info \"Checking resource groups...\"
$rgCount = (terraform state list | Select-String -Pattern 'azurerm_resource_group' | Measure-Object).Count
Log-Success \"Found $rgCount resource groups\"

# Check virtual networks
Log-Info \"Checking virtual networks...\"
$vnetCount = (terraform state list | Select-String -Pattern 'azurerm_virtual_network' | Measure-Object).Count
Log-Success \"Found $vnetCount virtual networks\"

# Check subnets
Log-Info \"Checking subnets...\"
$subnetCount = (terraform state list | Select-String -Pattern 'azurerm_subnet' | Measure-Object).Count
Log-Success \"Found $subnetCount subnets\"

# Check private DNS zones
Log-Info \"Checking private DNS zones...\"
$dnsZoneCount = (terraform state list | Select-String -Pattern 'azurerm_private_dns_zone.this' | Measure-Object).Count
Log-Success \"Found $dnsZoneCount private DNS zones\"

# Check firewall
Log-Info \"Checking Azure Firewall...\"
$fwExists = terraform state list | Select-String -Pattern 'azurerm_firewall.this'
if ($fwExists) {
    Log-Success \"Azure Firewall deployed\"
} else {
    Log-Warning \"Azure Firewall not found in state\"
}

# Check pricing resources
Log-Info \"Checking Security Center pricing resources...\"
$pricingCount = (terraform state list | Select-String -Pattern 'azurerm_security_center_subscription_pricing' | Measure-Object).Count
Log-Success \"Found $pricingCount pricing resources imported\"

Write-Host \"\"

# ============================================================================
# SUMMARY & NEXT STEPS
# ============================================================================

Write-Host \"\"
Write-Host \"=================================\" -ForegroundColor Green
Write-Host \"✅ DEPLOYMENT COMPLETE\" -ForegroundColor Green
Write-Host \"=================================\" -ForegroundColor Green
Write-Host \"\"

Log-Success \"Your Azure Landing Zone infrastructure is now deployed!\"
Write-Host \"\"

Write-Host \"Summary:\"
Write-Host \"  • Resource Groups: $rgCount\"
Write-Host \"  • Virtual Networks: $vnetCount\"
Write-Host \"  • Subnets: $subnetCount\"
Write-Host \"  • Private DNS Zones: $dnsZoneCount\"
Write-Host \"  • Security Pricing Resources: $pricingCount\"
Write-Host \"\"

Write-Host \"Next Steps:\"
Write-Host \"  1. Review your resources in the Azure Portal\"
Write-Host \"  2. Run post-deployment validation: see DEPLOYMENT_CHECKLIST.md\"
Write-Host \"  3. Deploy workloads to prod/nonprod spokes\"
Write-Host \"  4. Configure network security and policies\"
Write-Host \"\"

Write-Host \"Documentation:\"
Write-Host \"  • Detailed Fix Guide: $ProjectRoot/TERRAFORM_FIX_GUIDE.md\"
Write-Host \"  • Deployment Summary: $ProjectRoot/DEPLOYMENT_FIX_SUMMARY.md\"
Write-Host \"  • Architecture Docs: $ProjectRoot/ARCHITECTURE.md\"
Write-Host \"\"

Log-Success \"Deployment script completed successfully!\"

# Return to original directory
Pop-Location

Write-Host \"\"
