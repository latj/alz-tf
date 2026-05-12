# Azure Landing Zone — Deployment & Fix Scripts

This directory contains scripts to automate the deployment and remediation of the ALZ infrastructure.

## Quick Start

### **Windows Users** (PowerShell)
```powershell
powershell -ExecutionPolicy Bypass -File deploy-fixed-infrastructure.ps1
```

### **Linux/macOS Users** (Bash)
```bash
bash deploy-fixed-infrastructure.sh
```

---

## Available Scripts

### 1. **deploy-fixed-infrastructure** (Main Deployment)
Complete end-to-end deployment with all fixes applied.

**Files**:
- `deploy-fixed-infrastructure.ps1` (Windows/PowerShell)
- `deploy-fixed-infrastructure.sh` (Linux/macOS/Bash)

**What it does**:
1. Validates prerequisites (Terraform, Azure CLI)
2. Deploys networking + policies (without security module)
3. Imports existing Security Center pricing resources
4. Deploys full infrastructure including security module
5. Validates all resources deployed successfully

**Usage**:
```powershell
# PowerShell (Windows)
powershell -ExecutionPolicy Bypass -File deploy-fixed-infrastructure.ps1 -SubscriptionId \"71fc303d-592a-4360-8147-39b1daf37558\"

# Bash (Linux/macOS)
bash deploy-fixed-infrastructure.sh 71fc303d-592a-4360-8147-39b1daf37558
```

**Expected Output**: Full infrastructure deployed with validation summary

---

### 2. **import-security-pricing** (Security Pricing Import)
Automates importing of existing Security Center pricing resources.

**Files**:
- `import-security-pricing.bat` (Windows/Cmd)
- `import-security-pricing.sh` (Linux/macOS/Bash)

**What it does**:
1. Lists pricing resources to import (8 total)
2. Imports each into Terraform state
3. Reports success/failure summary

**Usage**:
```cmd
:: Windows Command Prompt
import-security-pricing.bat 71fc303d-592a-4360-8147-39b1daf37558

:: Or with no subscription ID (uses default)
import-security-pricing.bat
```

```bash
# Linux/macOS
bash import-security-pricing.sh 71fc303d-592a-4360-8147-39b1daf37558

# Or with no subscription ID (uses default)
bash import-security-pricing.sh
```

**Pricing Resources Imported**:
1. CloudPosture (CSPM)
2. VirtualMachines (Defender for Servers)
3. Containers (Defender for Containers)
4. SqlServers (Defender for SQL)
5. OpenSourceRelationalDatabases (Defender for OSS DB)
6. KeyVaults (Defender for Key Vault)
7. Arm (Defender for ARM)
8. StorageAccounts (Defender for Storage)

---

### 3. **Other Utility Scripts**

#### **bootstrap-backend.sh**
Sets up remote Terraform state backend in Azure Storage.
```bash
bash bootstrap-backend.sh -s <storage-account-name>
```

#### **validate-prerequisites.sh**
Validates your environment before deploying.
```bash
bash validate-prerequisites.sh
```

#### **teardown.sh**
Destroys all deployed infrastructure (use with caution!).
```bash
bash teardown.sh
```

---

## Deployment Strategy

### **Recommended Approach (Step-by-Step)**

1. **Validate Prerequisites**
   ```bash
   bash validate-prerequisites.sh
   ```

2. **Deploy Phase 1** (Networking & Policies)
   ```bash
   cd infra/terraform
   terraform init
   terraform plan -target=module.log_analytics -target=module.networking -target=module.policy
   terraform apply -target=module.log_analytics -target=module.networking -target=module.policy
   ```

3. **Import Security Pricing**
   ```bash
   bash scripts/import-security-pricing.sh 71fc303d-592a-4360-8147-39b1daf37558
   ```

4. **Deploy Phase 2** (Security Module)
   ```bash
   cd infra/terraform
   terraform plan
   terraform apply
   ```

### **Fast Approach (Automated)**

Run the full deployment script:

**Windows**:
```powershell
powershell -ExecutionPolicy Bypass -File scripts/deploy-fixed-infrastructure.ps1
```

**Linux/macOS**:
```bash
bash scripts/deploy-fixed-infrastructure.sh
```

---

## Troubleshooting

### **Script Won't Run (Permission Denied)**

**Linux/macOS**:
```bash
chmod +x scripts/*.sh
```

**PowerShell**:
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### **Import Script Fails**

1. **Check subscription ID**:
   ```bash
   az account show --query id -o tsv
   ```

2. **Verify RBAC permissions**:
   - Must have \"Security Admin\" or \"Owner\" role on subscription

3. **Check if resources exist**:
   ```bash
   az rest --method get \\
     --url \"/subscriptions/<sub-id>/providers/Microsoft.Security/pricings?api-version=2024-01-01\" \\
     -o json | jq '.value[] | {name: .name, tier: .properties.pricingTier}'
   ```

### **Terraform State Issues**

**Reset state** (if needed):
```bash
cd infra/terraform
rm -rf .terraform
terraform init
```

**Unlock state** (if locked):
```bash
terraform force-unlock <lock-id>
```

---

## Environment Variables

### Useful Azure CLI Variables

```bash
# Set default subscription
az account set --subscription \"71fc303d-592a-4360-8147-39b1daf37558\"

# Set output format
export AZURE_OUTPUT_FORMAT=json

# Enable debug logging
export AZURE_DEBUG=true
```

### Terraform Environment Variables

```bash
# Skip backend initialization
export TF_BACKEND=false

# Enable Terraform debug logging
export TF_LOG=DEBUG
export TF_LOG_PATH=terraform.log

# Set input to false for automation
export TF_INPUT=false
```

---

## Post-Deployment Validation

After running any deployment script, validate:

```bash
cd infra/terraform

# Check deployed resources
terraform state list

# Verify specific resources
terraform state show module.networking[0].azurerm_virtual_network.hub
terraform state show module.networking[0].azurerm_firewall.this

# Generate outputs
terraform output

# View cost estimate (if output defined)
terraform output -json | jq '.estimated_monthly_cost.value'
```

---

## Cleanup & Destruction

**CAUTION**: This destroys all deployed infrastructure!

```bash
cd infra/terraform
terraform destroy
```

Or use the teardown script:

```bash
bash scripts/teardown.sh
```

---

## Script Development

### Adding a New Script

1. Create script in `scripts/` directory
2. Add shebang: `#!/bin/bash` or `#!/bin/pwsh`
3. Add header comment with usage
4. Make executable: `chmod +x scripts/myscript.sh`
5. Update this README with usage instructions

### Testing Scripts

```bash
# Validate bash syntax
bash -n scripts/myscript.sh

# Run with debug output
bash -x scripts/myscript.sh

# Dry run (echo commands instead of executing)
bash -n scripts/myscript.sh
```

---

## Support & Documentation

- 📖 **Fix Guide**: See [../TERRAFORM_FIX_GUIDE.md](../TERRAFORM_FIX_GUIDE.md)
- 📋 **Deployment Summary**: See [../DEPLOYMENT_FIX_SUMMARY.md](../DEPLOYMENT_FIX_SUMMARY.md)
- 🏗️ **Architecture**: See [../ARCHITECTURE.md](../ARCHITECTURE.md)
- ✅ **Checklist**: See [../DEPLOYMENT_CHECKLIST.md](../DEPLOYMENT_CHECKLIST.md)

---

**Last Updated**: May 11, 2026  
**Status**: Ready for Production
