# Scalable Azure Landing Zone - Deployment Guide

This guide walks through deploying a production-ready Azure Landing Zone with hub-spoke networking, Azure Firewall, Private DNS Resolution, and comprehensive security policies.

## Quick Start

### 1. Prerequisites Check
```bash
# Verify Terraform version
terraform --version  # Should be >= 1.5.0

# Verify Azure CLI
az --version

# Login to Azure
az login
```

### 2. Update terraform.tfvars
```bash
cp infra/terraform/terraform.tfvars.example infra/terraform/terraform.tfvars
```

Edit `infra/terraform/terraform.tfvars`:
```hcl
# Core Configuration
subscription_id = "<YOUR_SUBSCRIPTION_ID>"
location        = "eastus2"
company_name    = "acme"      # Will be used in all resource names
environment     = "prod"

# Networking (Hub-Spoke)
hub_address_space           = "10.0.0.0/16"
prod_spoke_address_space    = "10.1.0.0/16"
nonprod_spoke_address_space = "10.2.0.0/16"

# Monitoring
log_retention_in_days = 90

# Security Contact
security_contact_email = "security@acme.com"

# Defender for Cloud (Prod = true, NonProd = false)
enable_defender_for_servers    = true
enable_defender_for_containers = true
enable_defender_for_databases  = true
enable_defender_for_key_vault  = true

# Tags (Optional)
tags = {
  CostCenter = "Platform"
}
```

### 3. Deploy Management Groups (ONE-TIME, Tenant-level)

Management groups must be deployed separately as they require tenant-level permissions.

```bash
cd infra/terraform/modules/management-groups

# Initialize
terraform init

# Deploy with required variables
terraform apply \
  -var='subscription_id=<YOUR_SUBSCRIPTION_ID>' \
  -var='company_name=acme' \
  -var='prod_subscription_id=<PROD_SUBSCRIPTION_ID>' \
  -var='nonprod_subscription_id=<NONPROD_SUBSCRIPTION_ID>'

# Verify outputs
terraform output

# Return to root
cd ../../..
```

**Note**: You only need to deploy management groups once. They exist at the tenant level and are shared.

### 4. Bootstrap Terraform Backend

Create Azure Storage Account for remote state:
```bash
scripts/bootstrap-backend.sh -s tfstate20250511
```

This script:
- Creates resource group: `rg-terraform-state`
- Creates storage account: `tfstate20250511`
- Creates blob container: `tfstate`
- Enables versioning and soft delete
- Displays connection information

### 5. Deploy Landing Zone

```bash
cd infra/terraform

# Authenticate locally before initializing the remote backend
az login

# Initialize with remote backend
terraform init \
  -backend-config="storage_account_name=tfstate20250511" \
  -backend-config="container_name=tfstate" \
  -backend-config="key=landing-zone.tfstate" \
  -backend-config="resource_group_name=rg-terraform-state"


For CI/CD with workload identity federation, add `-backend-config="use_oidc=true"` to the same `terraform init` command.
# Plan deployment
terraform plan -out=tfplan

# Apply (this takes ~10-15 minutes)
terraform apply tfplan

# View outputs
terraform output
```

## Architecture Verification

After deployment, verify your infrastructure:

### 1. Check VNet Peering
```bash
# List all VNet peerings
az network vnet peering list -g rg-acme-prod-networking

# Verify hub-to-prod peering
az network vnet peering show \
  -g rg-acme-prod-networking \
  -n peer-hub-to-prod \
  --vnet-name vnet-acme-prod-hub
```

### 2. Verify Firewall
```bash
# Get firewall IP
az network firewall list -g rg-acme-prod-networking -o table

# Check firewall policy rules
az network firewall policy list -g rg-acme-prod-networking

# View routing through firewall
az network route-table list -g rg-acme-prod-networking -o table
```

### 3. Test DNS Resolution
```bash
# Check private DNS zones
az network private-dns zone list -g rg-acme-prod-networking -o table

# Verify zone links to VNets
az network private-dns zone network-link list \
  -g rg-acme-prod-networking \
  -z privatelink.blob.core.windows.net -o table
```

### 4. Verify Policies
```bash
# List policy assignments
az policy assignment list \
  --scope /subscriptions/<SUBSCRIPTION_ID> -o table

# Check policy compliance
az policy state list \
  --filter "PolicyDefinitionAction eq 'audit'" \
  --query "[].{Policy: policyDefinitionName, Compliance: complianceState}" -o table
```

### 5. Check Log Analytics
```bash
# Get LAW ID
terraform output log_analytics_workspace_id

# Query recent logs
az monitor log-analytics query \
  -w <LOG_ANALYTICS_WORKSPACE_ID> \
  --analytics-query "AzureActivity | top 10 by TimeGenerated"
```

## Network Testing

### Test Connectivity Between Spokes

#### Scenario 1: Deploy test VMs in each spoke
```bash
# In Production Spoke App Subnet
az vm create \
  --name vm-prod-test \
  --resource-group rg-acme-prod-networking \
  --image UbuntuLTS \
  --vnet-name vnet-acme-prod-prod \
  --subnet snet-app \
  --public-ip-sku Standard

# In Non-Production Spoke App Subnet  
az vm create \
  --name vm-nonprod-test \
  --resource-group rg-acme-prod-networking \
  --image UbuntuLTS \
  --vnet-name vnet-acme-prod-nonprod \
  --subnet snet-app \
  --public-ip-sku Standard
```

#### Scenario 2: Test communication
```bash
# Get private IPs
PROD_IP=$(az vm list-ip-addresses -g rg-acme-prod-networking -n vm-prod-test -o tsv --query "[0].virtualMachine.network.privateIpAddresses[0]")
NONPROD_IP=$(az vm list-ip-addresses -g rg-acme-prod-networking -n vm-nonprod-test -o tsv --query "[0].virtualMachine.network.privateIpAddresses[0]")

# From prod VM, ping non-prod (via firewall)
az vm run-command invoke \
  -g rg-acme-prod-networking \
  -n vm-prod-test \
  --command-id RunShellScript \
  --scripts "ping -c 4 $NONPROD_IP"
```

### Test Private Endpoint Resolution

```bash
# Deploy storage account in hub
az storage account create \
  --name stacmeprod$(date +%s) \
  --resource-group rg-acme-prod-networking \
  --location eastus2

# Create private endpoint in spoke
az network private-endpoint create \
  --name pe-blob \
  --resource-group rg-acme-prod-networking \
  --vnet-name vnet-acme-prod-prod \
  --subnet snet-shared \
  --private-connection-resource-id /subscriptions/<SUB>/resourceGroups/rg-acme-prod-networking/providers/Microsoft.Storage/storageAccounts/<STORAGE_ACCOUNT> \
  --group-ids blob \
  --connection-name blob-connection

# Test DNS resolution from VM
az vm run-command invoke \
  -g rg-acme-prod-networking \
  -n vm-prod-test \
  --command-id RunShellScript \
  --scripts "nslookup <storage_account>.blob.core.windows.net"
```

## Cost Analysis

Run this command to estimate your monthly costs:

```bash
# Basic estimate
echo "Monthly Cost Estimates:"
echo "======================"
echo "Azure Firewall (Standard): \$37.50 (~$1.25/hour)"
echo "Private DNS Resolver Inbound: \$30/month (~$1/hour)"
echo "Private DNS Resolver Outbound: \$30/month (~$1/hour)"
echo "Log Analytics (5GB/day): \$300-400/month"
echo "VNet Peering: Free (within region)"
echo "Private DNS Zones: Free (15 zones)"
echo "-----"
echo "Total Estimate: \$430-500/month"
echo ""
echo "Optimization Tips:"
echo "- Consolidate firewalls if deploying multiple landing zones"
echo "- Reduce Log Analytics retention if compliance allows"
echo "- Use firewall policy for multiple resources"
```

## Maintenance Tasks

### Monthly
```bash
# Review policy compliance
az policy state list \
  --filter "PolicyDefinitionAction eq 'audit'" \
  --query "[].{Policy: policyDefinitionName, Compliance: complianceState, Count: count}" \
  -o table

# Check firewall logs
az monitor log-analytics query \
  -w <LOG_ANALYTICS_WORKSPACE_ID> \
  --analytics-query "AzureDiagnostics | where ResourceType == 'AZUREFIREWALLS' | summarize count() by OperationName"
```

### Quarterly
```bash
# Review and update firewall rules
az network firewall policy rule-collection-group list \
  -g rg-acme-prod-networking \
  --policy-name fwp-acme-prod -o table

# Check policy effectiveness
az policy state list \
  --filter "PolicyDefinitionAction eq 'modify'" \
  --query "[].{Policy: policyDefinitionName, NonCompliant: complianceState}" \
  -o table
```

### Annually
```bash
# Review and update DNS forwarding rules
az network private-dns resolver dns-forwarding-ruleset list \
  -g rg-acme-prod-networking -o table

# Audit management group structure
az account management-group entities list \
  -g mg-acme --query "[].displayName"
```

## Troubleshooting

### Issue: Policy remediation fails
**Cause**: Missing role assignment for managed identity
```bash
# Get managed identity from policy assignment
IDENTITY_ID=$(az policy assignment show \
  --name inherit-env-tag \
  --scope /subscriptions/<SUB> \
  --query identity.principalId -o tsv)

# Assign role
az role assignment create \
  --role "Tag Contributor" \
  --assignee-object-id $IDENTITY_ID \
  --scope /subscriptions/<SUB>
```

### Issue: Firewall blocking legitimate traffic
**Solution**: Add application rule
```bash
az network firewall policy rule-collection-group create \
  -g rg-acme-prod-networking \
  -n CustomRules \
  --policy-name fwp-acme-prod \
  --priority 200 \
  --rule-collection-groups "[your-rule-collection]"
```

### Issue: DNS not resolving
**Solution**: Verify DNS zone link
```bash
# List zone links
az network private-dns zone network-link list \
  -g rg-acme-prod-networking \
  -z privatelink.blob.core.windows.net

# Test from VM
az vm run-command invoke \
  -g rg-acme-prod-networking \
  -n vm-prod-test \
  --command-id RunShellScript \
  --scripts "nslookup 8.8.8.8"
```

## Cleanup

To destroy all resources:

```bash
# Destroy landing zone
cd infra/terraform
terraform destroy

# Destroy management groups (if needed - requires tenant role)
cd modules/management-groups
terraform destroy

# Cleanup Terraform state
az storage account delete \
  -n tfstate20250511 \
  -g rg-terraform-state
```

## Next Steps

1. **Add Spoke-Specific Resources**
   - Deploy application workloads in spoke app subnets
   - Create private endpoints in shared subnets
   - Configure database instances in data subnets

2. **Implement Advanced Networking**
   - Add VPN Gateway for hybrid connectivity
   - Configure site-to-site connections
   - Setup ExpressRoute peering

3. **Enhance Security**
   - Implement Azure Web Application Firewall (WAF)
   - Deploy DDoS Protection Standard
   - Configure Azure Bastion for VM access

4. **Advanced Monitoring**
   - Create Log Analytics workbooks
   - Setup alerts for policy violations
   - Configure action groups for notifications

5. **Cost Management**
   - Implement budget alerts
   - Setup cost anomaly detection
   - Review reserved instance options

