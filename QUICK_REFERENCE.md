# Azure Landing Zone - Quick Reference Card

**Print this page for quick access during deployment**

---

## Quick Start Commands

```bash
# 1. Validate prerequisites
scripts/validate-prerequisites.sh

# 2. Deploy Management Groups (ONE-TIME, separate)
cd infra/terraform/modules/management-groups
terraform init
terraform apply \
  -var='subscription_id=<UUID>' \
  -var='company_name=acme' \
  -var='prod_subscription_id=<PROD_UUID>' \
  -var='nonprod_subscription_id=<NONPROD_UUID>'

# 3. Bootstrap backend (ONE-TIME)
cd ../../..
scripts/bootstrap-backend.sh -s tfstate20250511

# 4. Deploy landing zone (configure subscription IDs in terraform.tfvars - leave empty to skip components)
cd infra/terraform
terraform init -upgrade
terraform plan -out=tfplan
terraform apply tfplan

# 5. View outputs
terraform output
terraform output hub_vnet_id
terraform output spoke_vnet_ids
terraform output firewall_private_ip
```

---

## Key Network Ranges

| Component | CIDR | Subnets |
|-----------|------|---------|
| **Hub** | 10.0.0.0/16 | AzureFirewall: 10.0.0.0/24, DNS-In: 10.0.1.0/24, DNS-Out: 10.0.2.0/24, Gateway: 10.0.3.0/24 |
| **Prod Spoke** | 10.1.0.0/16 | App: 10.1.0.0/20, Data: 10.1.16.0/20, Shared: 10.1.24.0/24 |
| **NonProd Spoke** | 10.2.0.0/16 | App: 10.2.0.0/20, Data: 10.2.16.0/20, Shared: 10.2.24.0/24 |

---

## terraform.tfvars Template

```hcl
# Multi-Subscription Configuration
networking_subscription_id = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"  # Hub VNet, Firewall, DNS
management_subscription_id = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"  # Monitoring, Policies, Security
prod_subscription_id       = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"  # Production workloads
devtest_subscription_id    = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"  # Dev/Test workloads

location     = "eastus2"
company_name = "acme"
environment  = "prod"

hub_address_space           = "10.0.0.0/16"
prod_spoke_address_space    = "10.1.0.0/16"
nonprod_spoke_address_space = "10.2.0.0/16"

security_contact_email = "security@acme.com"
enable_defender_for_servers = true

tags = {
  environment = "prod"
  team        = "platform"
}
```

---

## Verification Commands

```bash
# Verify Management Groups
az account management-group entities list -o table

# Verify VNets
az network vnet list -g rg-acme-prod-networking -o table

# Verify Firewall
az network firewall show -g rg-acme-prod-networking -n fw-acme-prod

# Verify DNS Zones
az network private-dns zone list -g rg-acme-prod-networking -o table

# Verify Peering
az network vnet peering list -g rg-acme-prod-networking -o table

# Verify Policies
az policy assignment list --scope /subscriptions/{subscription_id} -o table

# Verify Log Analytics
az monitor log-analytics workspace list -g rg-acme-prod-monitoring -o table
```

---

## Private DNS Zones (All 15)

Storage: `blob.core.windows.net`, `file.core.windows.net`, `queue.core.windows.net`, `table.core.windows.net`

Databases: `database.windows.net`, `postgres.database.azure.com`, `mysql.database.azure.com`

Services: `vaultcore.azure.net`, `redis.cache.azure.net`, `servicebus.windows.net`, `eventhub.windows.net`

AI/Web: `api.azureml.ms`, `notebooks.azure.net`, `azurewebsites.net`

---

## Firewall Rules Summary

**Application Rules**:
- AllowAzureServices: `*.azure.com`, `*.microsoft.com`, `*.windows.net` (HTTP/HTTPS)

**Network Rules**:
- AllowNTP: UDP 123 (time sync)
- AllowDNS: UDP 53 (DNS queries)

---

## Resource Naming Convention

```
{component}-{company}-{environment}

Examples:
- vnet-acme-prod-hub
- vnet-acme-prod-prod
- fw-acme-prod
- law-acme-prod
- rg-acme-prod-networking
- rg-acme-prod-monitoring
- fwp-acme-prod
- dnsr-acme-prod
```

---

## Common Terraform Commands

```bash
# Validate syntax
terraform validate

# Format files
terraform fmt -recursive

# View plan
terraform plan

# Apply specific resource
terraform apply -target=module.networking

# Destroy resources
terraform destroy

# Import state
terraform import 'module.networking.azurerm_virtual_network.hub' /subscriptions/.../virtualNetworks/...

# Show state
terraform show
terraform state list
terraform state show 'module.networking.azurerm_firewall.this'
```

---

## Troubleshooting Quick Fixes

| Problem | Solution |
|---------|----------|
| "Unsupported argument" error | Update AzureRM provider: `terraform init -upgrade` |
| Firewall not routing traffic | Check route table, verify 0.0.0.0/0 → firewall IP |
| DNS not resolving | Verify DNS zone link, check resolver endpoints active |
| Peering failed | Check address spaces don't overlap, verify permissions |
| Policy not remediated | Check managed identity role assignments, verify scope |
| tfplan not applying | Ensure lock file present, check permissions on storage account |

---

## Cost Tracking

All resources tagged with:
- `environment`: prod/nonprod
- `team`: platform
- `CostCenter`: allocation code

**Azure Portal**: 
1. Cost Analysis → Filter by tag
2. Cost Management → Budgets → Set alerts
3. Recommendations → Apply reserved instances

---

## Post-Deployment Checklist

- [ ] All 3 VNets created (hub + 2 spokes)
- [ ] Firewall operational
- [ ] DNS zones linked (15 zones × 3 VNets = 45 links)
- [ ] Peering connections active (4 connections)
- [ ] Policies enforced (8 assignments)
- [ ] Log Analytics receiving data
- [ ] Management groups hierarchical
- [ ] terraform.tfstate in storage account

---

## Documentation Map

| Document | Purpose | Read When |
|----------|---------|-----------|
| README.md | Navigation | Starting deployment |
| IMPLEMENTATION_SUMMARY.md | Overview | Need quick understanding |
| ARCHITECTURE.md | Deep-dive | Need design details |
| DEPLOYMENT_GUIDE.md | Step-by-step | During deployment |
| CODE_REFERENCE.md | Code details | Customizing code |
| ARCHITECTURE_VISUALS.md | Diagrams | Need visual reference |
| DEPLOYMENT_CHECKLIST.md | Verification | After deployment |

---

## Support Resources

**Microsoft Docs**:
- [Azure Landing Zones](https://learn.microsoft.com/azure/cloud-adoption-framework/ready/landing-zone/)
- [Hub-Spoke Reference](https://learn.microsoft.com/azure/architecture/reference-architectures/hybrid-networking/hub-spoke)
- [Azure Firewall](https://learn.microsoft.com/azure/firewall/overview)
- [Private DNS Resolver](https://learn.microsoft.com/azure/dns/dns-private-resolver-overview)

**Terraform Registry**:
- [AzureRM Provider](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
- [Azure Verified Modules](https://learn.microsoft.com/en-us/azure/architecture/guide/verified-modules/module-registry)

---

## Key Contact Info

**Deployment Contacts**:
- Azure Admin: ___________________
- Network Team: ___________________
- Security Lead: ___________________
- Billing: ___________________

**For Issues**:
1. Check DEPLOYMENT_GUIDE.md troubleshooting section
2. Review terraform logs: `TF_LOG=DEBUG terraform apply`
3. Check Azure Activity Log in portal
4. Contact deployment team

---

## Version Information

- **Terraform**: >= 1.5.0
- **AzureRM Provider**: ~> 4.0
- **Azure CLI**: Latest version recommended
- **Implementation Date**: May 2025
- **Status**: Production Ready ✅

---

**Keep this card with your deployment team!**

