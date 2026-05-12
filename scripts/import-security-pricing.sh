#!/bin/bash

# =============================================================================
# Azure Landing Zone — Terraform Security Center Pricing Import Script
# =============================================================================
# This script automates importing existing Security Center pricing resources
# into Terraform state. Run this AFTER terraform apply (without security module).
# =============================================================================

set -e

SUBSCRIPTION_ID="${1:-71fc303d-592a-4360-8147-39b1daf37558}"
TF_DIR="$(cd \"$(dirname \"${BASH_SOURCE[0]}\")\" && pwd)/infra/terraform"

echo \"================================================================\"
echo \"Azure Landing Zone — Importing Security Center Pricing Resources\"
echo \"================================================================\"
echo \"\"
echo \"Subscription ID: $SUBSCRIPTION_ID\"
echo \"Terraform Dir: $TF_DIR\"
echo \"\"

if [ ! -d \"$TF_DIR\" ]; then
    echo \"❌ ERROR: Terraform directory not found at $TF_DIR\"
    exit 1
fi

cd \"$TF_DIR\"

# Define the pricing resources to import
declare -A RESOURCES=(
    [\"CloudPosture\"]=\"CloudPosture\"
    [\"VirtualMachines\"]=\"servers\"
    [\"Containers\"]=\"containers\"
    [\"SqlServers\"]=\"sql\"
    [\"OpenSourceRelationalDatabases\"]=\"oss_db\"
    [\"KeyVaults\"]=\"keyvault\"
    [\"Arm\"]=\"arm\"
    [\"StorageAccounts\"]=\"storage\"
)

echo \"📋 Starting imports...\"
echo \"\"

FAILED=0
SUCCEEDED=0

for PRICING_TYPE in \"${!RESOURCES[@]}\"; do
    RESOURCE_NAME=\"${RESOURCES[$PRICING_TYPE]}\"
    RESOURCE_ID=\"/subscriptions/$SUBSCRIPTION_ID/providers/Microsoft.Security/pricings/$PRICING_TYPE\"
    
    echo \"⏳ Importing: $PRICING_TYPE (terraform resource: azurerm_security_center_subscription_pricing.$RESOURCE_NAME)\"
    
    if terraform import \"module.security[0].azurerm_security_center_subscription_pricing.$RESOURCE_NAME\" \"$RESOURCE_ID\" 2>&1; then
        echo \"✅ Successfully imported $PRICING_TYPE\"
        ((SUCCEEDED++))
    else
        echo \"❌ Failed to import $PRICING_TYPE\"
        ((FAILED++))
    fi
    echo \"\"
done

echo \"================================================================\"
echo \"Import Summary\"
echo \"================================================================\"
echo \"✅ Succeeded: $SUCCEEDED\"
echo \"❌ Failed: $FAILED\"
echo \"\"

if [ $FAILED -eq 0 ]; then
    echo \"🎉 All pricing resources imported successfully!\"
    echo \"\"
    echo \"Next Steps:\"
    echo \"1. Review the security module code in modules/security/main.tf\"
    echo \"2. Uncomment the security module in main.tf\"
    echo \"3. Run: terraform plan\"
    echo \"4. Run: terraform apply\"
    echo \"\"
    exit 0
else
    echo \"⚠️  Some imports failed. Check the errors above.\"
    echo \"\"
    echo \"Troubleshooting:\"
    echo \"1. Verify subscription ID is correct: $SUBSCRIPTION_ID\"
    echo \"2. Verify you have 'Security Admin' role on the subscription\"
    echo \"3. Verify the security module is NOT uncommented in main.tf\"
    echo \"\"
    exit 1
fi
