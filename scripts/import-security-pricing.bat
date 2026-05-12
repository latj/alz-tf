@echo off
REM =============================================================================
REM Azure Landing Zone — Terraform Security Center Pricing Import Script
REM =============================================================================
REM This script automates importing existing Security Center pricing resources
REM into Terraform state. Run this AFTER terraform apply (without security module).
REM =============================================================================

setlocal enabledelayedexpansion

set SUBSCRIPTION_ID=%1
if \"\" equ \"!SUBSCRIPTION_ID!\" set SUBSCRIPTION_ID=71fc303d-592a-4360-8147-39b1daf37558

set TF_DIR=%~dp0..\infra\terraform

echo.
echo ================================================================
echo Azure Landing Zone — Importing Security Center Pricing Resources
echo ================================================================
echo.
echo Subscription ID: !SUBSCRIPTION_ID!
echo Terraform Dir: !TF_DIR!
echo.

if not exist \"!TF_DIR!\" (
    echo ❌ ERROR: Terraform directory not found at !TF_DIR!
    exit /b 1
)

cd /d \"!TF_DIR!\"

echo 📋 Starting imports...
echo.

set SUCCEEDED=0
set FAILED=0

REM Define pricing resources
set \"ResourceTypes[0]=CloudPosture:cspm\"
set \"ResourceTypes[1]=VirtualMachines:servers\"
set \"ResourceTypes[2]=Containers:containers\"
set \"ResourceTypes[3]=SqlServers:sql\"
set \"ResourceTypes[4]=OpenSourceRelationalDatabases:oss_db\"
set \"ResourceTypes[5]=KeyVaults:keyvault\"
set \"ResourceTypes[6]=Arm:arm\"
set \"ResourceTypes[7]=StorageAccounts:storage\"

REM Note: Batch doesn't support associative arrays well, so we use indexed arrays with : delimiter

for /l %%i in (0,1,7) do (
    setlocal enabledelayedexpansion
    set \"pair=!ResourceTypes[%%i]!\"
    for /f \"tokens=1,2 delims=:\" %%a in (\"!pair!\") do (
        set PRICING_TYPE=%%a
        set RESOURCE_NAME=%%b
        set RESOURCE_ID=/subscriptions/!SUBSCRIPTION_ID!/providers/Microsoft.Security/pricings/!PRICING_TYPE!
        
        echo ⏳ Importing: !PRICING_TYPE! (terraform resource: azurerm_security_center_subscription_pricing.!RESOURCE_NAME!)
        
        terraform import \"module.security[0].azurerm_security_center_subscription_pricing.!RESOURCE_NAME!\" \"!RESOURCE_ID!\" >nul 2>&1
        
        if !ERRORLEVEL! equ 0 (
            echo ✅ Successfully imported !PRICING_TYPE!
            set /a SUCCEEDED+=1
        ) else (
            echo ❌ Failed to import !PRICING_TYPE!
            set /a FAILED+=1
        )
        echo.
    )
    endlocal
)

echo ================================================================
echo Import Summary
echo ================================================================
echo ✅ Succeeded: !SUCCEEDED!
echo ❌ Failed: !FAILED!
echo.

if !FAILED! equ 0 (
    echo 🎉 All pricing resources imported successfully!
    echo.
    echo Next Steps:
    echo 1. Review the security module code in modules/security/main.tf
    echo 2. Uncomment the security module in main.tf
    echo 3. Run: terraform plan
    echo 4. Run: terraform apply
    echo.
    exit /b 0
) else (
    echo ⚠️  Some imports failed. Check the errors above.
    echo.
    echo Troubleshooting:
    echo 1. Verify subscription ID is correct: !SUBSCRIPTION_ID!
    echo 2. Verify you have 'Security Admin' role on the subscription
    echo 3. Verify the security module is NOT uncommented in main.tf
    echo.
    exit /b 1
)
