# Azure Landing Zone Architecture (Scalable Hub-Spoke)

This document outlines the comprehensive Azure Landing Zone architecture implemented with Terraform, designed for enterprise-grade workload deployment with security, compliance, and observability at its core.

## Architecture Overview

The implementation follows the Azure Well-Architected Framework with a hub-and-spoke network topology, centralized security policies, comprehensive monitoring, and hierarchical management group structure.

```
┌─────────────────────────────────────────────────────────────────┐
│                    Management Groups (Tenant)                    │
│  ┌────────────────────────────────────────────────────────────┐  │
│  │  Root Management Group                                     │  │
│  │  ├── Platform Management Group                             │  │
│  │  │   └── Shared Services Subscriptions                     │  │
│  │  └── Landing Zones Management Group                        │  │
│  │      ├── Production Landing Zone (Prod Sub)                │  │
│  │      └── Non-Production Landing Zone (NonProd Sub)         │  │
│  └────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                    Network Architecture                           │
│  ┌────────────────────────────────────────────────────────────┐  │
│  │  Hub VNet (10.0.0.0/16)                                    │  │
│  │  ├── AzureFirewallSubnet (10.0.0.0/24)                     │  │
│  │  │   └── Azure Firewall (Standard)                         │  │
│  │  │       └── Firewall Policy with Rule Groups              │  │
│  │  ├── DNS Resolver Inbound (10.0.1.0/24)                    │  │
│  │  │   └── Handles on-premises DNS queries                   │  │
│  │  ├── DNS Resolver Outbound (10.0.2.0/24)                   │  │
│  │  │   └── Routes DNS queries to public resolvers            │  │
│  │  ├── GatewaySubnet (10.0.3.0/24)                           │  │
│  │  │   └── VPN/ExpressRoute gateway (optional)               │  │
│  │  └── Private DNS Zones                                     │  │
│  │      └── 15 zones for private endpoints                    │  │
│  │                                                             │  │
│  ├─ Prod Spoke VNet (10.1.0.0/16) ──── VNet Peering ─────┐  │  │
│  │   ├── App Subnet (10.1.0.0/20)                           │  │
│  │   ├── Data Subnet (10.1.16.0/20)                         │  │
│  │   └── Shared Subnet (10.1.24.0/24)                       │  │
│  │       └── Route Table → Firewall (0.0.0.0/0)             │  │
│  │                                                             │  │
│  └─ NonProd Spoke VNet (10.2.0.0/16) ─ VNet Peering ─────┘  │  │
│      ├── App Subnet (10.2.0.0/20)                             │  │
│      ├── Data Subnet (10.2.16.0/20)                           │  │
│      └── Shared Subnet (10.2.24.0/24)                         │  │
│          └── Route Table → Firewall (0.0.0.0/0)               │  │
│                                                                  │  │
│  Private DNS Zones Linked to All VNets:                        │  │
│  - privatelink.blob.core.windows.net                           │  │
│  - privatelink.vaultcore.azure.net                             │  │
│  - privatelink.database.windows.net                            │  │
│  - privatelink.azurewebsites.net                               │  │
│  - ... and 11 more                                             │  │
│  └────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                    Monitoring & Compliance                       │
│  ┌────────────────────────────────────────────────────────────┐  │
│  │  Log Analytics Workspace                                   │  │
│  │  ├── Activity Log Diagnostics                              │  │
│  │  ├── Firewall Logs & Metrics                               │  │
│  │  ├── Network Diagnostic Logs                               │  │
│  │  └── Resource Compliance Data                              │  │
│  │                                                             │  │
│  │  Azure Policies                                             │  │
│  │  ├── Microsoft Cloud Security Benchmark (Audit)            │  │
│  │  ├── Allowed Locations                                     │  │
│  │  ├── Required Tags (environment, team)                     │  │
│  │  ├── Tag Inheritance                                       │  │
│  │  └── Activity Log Diagnostics (DINE)                       │  │
│  │                                                             │  │
│  │  Defender for Cloud                                         │  │
│  │  ├── Defender for Servers (Prod only)                      │  │
│  │  ├── Defender for Databases (Prod only)                    │  │
│  │  ├── Defender for Containers                               │  │
│  │  ├── Defender for Key Vault                                │  │
│  │  └── Defender for Storage                                  │  │
│  └────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

## Multi-Subscription Architecture

This implementation supports **multi-subscription deployment** for better separation of concerns, security isolation, and cost management.

### Subscription Separation Strategy

**1. Networking/Connectivity Subscription**
- **Purpose**: Centralized network infrastructure and connectivity
- **Resources Deployed**: Hub VNet, Azure Firewall, Private DNS Resolver, VNets, Subnets
- **Benefits**: Network isolation, dedicated networking team management, centralized security
- **Resource Group**: `rg-{company}-{env}-networking`

**2. Management Subscription**
- **Purpose**: Centralized monitoring, governance, and security management
- **Resources Deployed**: Log Analytics Workspace, Azure Policies, Defender for Cloud
- **Benefits**: Platform-wide visibility, unified security posture, centralized compliance
- **Resource Group**: `rg-{company}-{env}-monitoring`

**3. Production Landing Zone Subscription**
- **Purpose**: Production workload deployment and management
- **Resources Deployed**: Future workloads (VMs, AKS, databases, applications)
- **Benefits**: Production isolation, compliance boundaries, dedicated cost center
- **Note**: No resources deployed by this Terraform config (reserved for workloads)

**4. DevTest Landing Zone Subscription**
- **Purpose**: Development and testing environment management
- **Resources Deployed**: Future dev/test workloads
- **Benefits**: Cost separation from production, environment isolation
- **Note**: No resources deployed by this Terraform config (reserved for workloads)

### Terraform Provider Configuration

The root module configures multiple Azure provider instances with aliases:

```hcl
# Networking provider
provider "azurerm" {
  alias           = "networking"
  subscription_id = var.networking_subscription_id
}

# Management provider
provider "azurerm" {
  alias           = "management"
  subscription_id = var.management_subscription_id
}

# Production provider (for future workloads)
provider "azurerm" {
  alias           = "prod"
  subscription_id = var.prod_subscription_id
}

# DevTest provider (for future workloads)
provider "azurerm" {
  alias           = "devtest"
  subscription_id = var.devtest_subscription_id
}
```

Each module specifies its target subscription via provider aliases in the `providers` block.

### Benefits of Multi-Subscription Architecture

**Security & Compliance:**
- Network-level isolation between environments
- Dedicated security monitoring per subscription
- Granular access control and RBAC
- Separate compliance boundaries

**Cost Management:**
- Clear cost allocation by subscription
- Environment-specific budgeting
- Chargeback to appropriate teams/cost centers
- Reserved instance optimization per subscription

**Operational Excellence:**
- Dedicated teams can manage their subscriptions
- Reduced blast radius for incidents
- Environment-specific policies and controls
- Simplified troubleshooting and monitoring

**Scalability:**
- Easy to add new subscriptions for new environments
- Independent scaling of networking vs. management resources
- Flexible workload placement based on requirements

---

### 1. Management Groups (Hierarchical Organization)
- **Root**: `mg-{company}` - Tenant-level root
- **Platform**: `mg-{company}-platform` - Shared services and platform infrastructure
- **Landing Zones**: `mg-{company}-landing-zones` - Subscription containers
  - Production: `mg-{company}-prod` (Production subscription)
  - Non-Production: `mg-{company}-nonprod` (Dev/Test subscriptions)

### 2. Hub-Spoke Network Topology

#### Hub VNet (10.0.0.0/16)
**Subnets:**
- **AzureFirewallSubnet** (10.0.0.0/24) - Contains Azure Firewall for centralized egress/ingress control
- **DNS Resolver Inbound** (10.0.1.0/24) - Private DNS Resolver for hybrid DNS resolution
- **DNS Resolver Outbound** (10.0.2.0/24) - Outbound DNS forwarding endpoint
- **GatewaySubnet** (10.0.3.0/24) - VPN/ExpressRoute gateway placeholder

**Key Features:**
- Centralized security enforcement via Azure Firewall
- Private DNS resolution for Azure services
- Hybrid connectivity ready (VPN/ExpressRoute)
- All traffic from spokes routes through firewall

#### Spoke VNets
**Production Spoke (10.1.0.0/16):**
- App Subnet (10.1.0.0/20) - App Service, Container Apps, etc.
- Data Subnet (10.1.16.0/20) - Databases, storage via private endpoints
- Shared Subnet (10.1.24.0/24) - Shared services

**Non-Production Spoke (10.2.0.0/16):**
- Same subnet structure as Production
- Enables consistent naming and management

**Spoke Features:**
- Peered to Hub with allow_forwarded_traffic enabled
- Default route (0.0.0.0/0) points to Firewall
- Private DNS zones linked for seamless private endpoint resolution

### 3. Azure Firewall Configuration

**Firewall Policy - Standard SKU:**
- **Application Rules**: Allow Azure cloud services (*.azure.com, *.microsoft.com, *.windows.net)
- **Network Rules**: 
  - Allow NTP (UDP 123) for time synchronization
  - Allow DNS (UDP 53) for name resolution
- **Rule Collection Groups**: Organized by priority for easy management

**Next Steps for Enhancement:**
- Add custom application rules based on workload requirements
- Implement NAT rules for hybrid scenarios
- Configure threat intelligence feeds

### 4. Private DNS Resolution

**Private DNS Resolver:**
- **Inbound Endpoint**: Accepts DNS queries from on-premises
- **Outbound Endpoint**: Forwards queries to Azure DNS (168.63.129.16)
- **Forwarding Rules**: Azure.com queries to Azure DNS

**Private DNS Zones (15 Zones):**
All linked to hub and spoke VNets:
- `privatelink.blob.core.windows.net` - Storage accounts
- `privatelink.vaultcore.azure.net` - Key Vaults
- `privatelink.database.windows.net` - Azure SQL
- `privatelink.postgres.database.azure.com` - PostgreSQL
- `privatelink.mysql.database.azure.com` - MySQL
- `privatelink.redis.cache.windows.net` - Azure Cache for Redis
- `privatelink.servicebus.windows.net` - Service Bus
- `privatelink.eventhub.windows.net` - Event Hubs
- `privatelink.webpubsub.azure.com` - Web PubSub
- `privatelink.azurewebsites.net` - App Service
- `privatelink.api.azureml.ms` - Azure ML
- `privatelink.notebooks.azure.net` - Azure ML Notebooks
- `privatelink.queue.core.windows.net` - Queue Storage
- `privatelink.table.core.windows.net` - Table Storage
- `privatelink.file.core.windows.net` - File Shares

### 5. Policies & Compliance

**Microsoft Cloud Security Benchmark (MCSB):**
- Audit-mode policy assignment
- Identifies resources not compliant with security best practices
- Foundation for continuous compliance

**Location Restrictions:**
- Enforce allowed Azure regions per subscription
- Prevent accidental deployments to restricted regions
- Separate policies for resources and resource groups

**Tag Requirements & Inheritance:**
- Mandatory `environment` tag on resource groups
- Mandatory `team` tag for cost allocation
- Automatic tag inheritance to child resources
- SystemAssigned managed identity for policy remediation

**Activity Log Diagnostics (DINE):**
- Deploy-if-Not-Exists policy
- Automatically streams Activity Log to Log Analytics
- Captures Administrative, Security, Alerts, Policy, ServiceHealth events

### 6. Monitoring & Logging

**Log Analytics Workspace:**
- Retention: 90 days (configurable)
- Daily quota: 5 GB (configurable)
- Connected to all diagnostics
- Query source for insights and alerts

**Defender for Cloud:**
- **Production**: Servers (P2), Databases, Key Vault, Storage
- **Non-Production**: Servers (Free), Containers, Key Vault
- Centralized security recommendations
- Threat detection and compliance reporting

## Module Structure

```
infra/
├── terraform/
│   ├── main.tf                    # Root module configuration
│   ├── variables.tf               # Input variables
│   ├── outputs.tf                 # Output values
│   ├── terraform.tfvars.example   # Example variables file
│   │
│   └── modules/
│       ├── management-groups/     # Tenant-level hierarchy
│       │   ├── main.tf
│       │   ├── variables.tf
│       │   └── outputs.tf
│       │
│       ├── networking/            # Hub-spoke topology
│       │   ├── main.tf           # VNets, subnets, peering
│       │   ├── variables.tf
│       │   └── outputs.tf
│       │
│       ├── monitoring/            # Log Analytics
│       │   ├── main.tf
│       │   ├── variables.tf
│       │   └── outputs.tf
│       │
│       ├── policy/                # Azure Policies
│       │   ├── main.tf
│       │   ├── variables.tf
│       │   └── outputs.tf
│       │
│       └── security/              # Defender for Cloud
│           ├── main.tf
│           ├── variables.tf
│           └── outputs.tf
│
└── scripts/
    ├── bootstrap-backend.sh       # Terraform state setup
    ├── validate-prerequisites.sh  # Validation script
    └── teardown.sh                # Cleanup script
```

## Deployment Flow

### Prerequisites
1. Azure subscription with at least Contributor role
2. Terraform >= 1.5.0
3. Azure CLI logged in: `az login`
4. For management groups: Tenant Administrator role required

### Step 1: Deploy Management Groups (Separate)
```bash
cd infra/terraform/modules/management-groups
terraform init
terraform apply \
  -var='subscription_id=<ANY_SUB_ID>' \
  -var='company_name=acme' \
  -var='prod_subscription_id=<PROD_SUB_ID>' \
  -var='nonprod_subscription_id=<NONPROD_SUB_ID>'
```

### Step 2: Bootstrap Terraform Backend
```bash
scripts/bootstrap-backend.sh -s <storage_account_name>
```

### Step 3: Deploy Landing Zone
```bash
cd infra/terraform
terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

## Configuration Examples

### Example terraform.tfvars
```hcl
subscription_id           = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
location                  = "eastus2"
company_name              = "acme"
environment               = "prod"
log_retention_in_days     = 90
security_contact_email    = "security@acme.com"

# Network configuration
hub_address_space           = "10.0.0.0/16"
prod_spoke_address_space    = "10.1.0.0/16"
nonprod_spoke_address_space = "10.2.0.0/16"

# Security
enable_defender_for_servers    = true
enable_defender_for_containers = true
enable_defender_for_databases  = true
enable_defender_for_key_vault  = true

# Tags
tags = {
  CostCenter = "Platform"
  DataClassification = "Internal"
  Criticality = "High"
}
```

## Outputs

After deployment, retrieve key values:

```bash
terraform output hub_vnet_id              # Hub VNet ID
terraform output spoke_vnet_ids           # Spoke VNet IDs
terraform output firewall_private_ip      # Firewall private IP
terraform output log_analytics_workspace_id # LAW ID
terraform output private_dns_zones        # Created DNS zones
```

## Security Features

1. **Network Segmentation**
   - Hub-spoke isolation
   - Network Security Groups on all subnets
   - Firewall egress filtering

2. **Data Protection**
   - Private endpoints via private DNS zones
   - Private DNS resolver for hybrid connectivity
   - Subnet delegation for managed services

3. **Access Control**
   - Management groups for RBAC organization
   - Principle of least privilege via policies
   - Managed identity for policy remediation

4. **Monitoring & Detection**
   - Centralized logging to Log Analytics
   - Activity Log streaming
   - Defender for Cloud threat detection
   - Policy compliance tracking

5. **Compliance**
   - Microsoft Cloud Security Benchmark audit
   - Tag enforcement for cost allocation
   - Resource location restrictions
   - Audit trail preservation

## Advanced Customization

### Adding Custom Firewall Rules
Edit `modules/networking/main.tf` to add application/network rules to `azurerm_firewall_policy_rule_collection_group`.

### Expanding Private DNS Zones
Modify `local.private_dns_zones` list in `modules/networking/main.tf` to add service-specific zones.

### Custom Policy Assignments
Extend `modules/policy/main.tf` with additional policy initiatives aligned to your compliance requirements.

### Hybrid Connectivity
1. Deploy VPN Gateway in GatewaySubnet
2. Configure site-to-site VPN connections
3. Update DNS forwarding rules for on-premises domains
4. Adjust firewall rules for hybrid traffic

## Cost Optimization

- **Firewall**: Standard tier ~$1.25/hour (always-on cost)
- **Log Analytics**: Based on ingestion (5 GB/day default = ~$300-400/month)
- **Private DNS Resolver**: ~$1/endpoint/hour
- **VNet Peering**: Free within region
- **Policies**: Free

Recommended optimizations:
- Use firewall policies for multiple firewalls (amortize costs)
- Adjust Log Analytics retention based on compliance needs
- Implement budget alerts via variables
- Use reserved instances for persistent resources

## Troubleshooting

### Policy Remediation Failures
Ensure role assignments are created with proper principals:
```bash
az role assignment create \
  --role "Tag Contributor" \
  --assignee-object-id <POLICY_MANAGED_IDENTITY_ID> \
  --scope /subscriptions/<SUBSCRIPTION_ID>
```

### DNS Resolution Issues
1. Verify private DNS zone links to VNets
2. Test DNS resolver inbound endpoint IP
3. Check firewall DNS rules (port 53 UDP)

### Firewall Connectivity Issues
1. Verify spoke route tables point to firewall IP
2. Check application/network rules in firewall policy
3. Review firewall logs in Log Analytics

## References

- [Azure Landing Zones](https://docs.microsoft.com/azure/cloud-adoption-framework/ready/landing-zone/)
- [Hub-Spoke Network Topology](https://docs.microsoft.com/azure/architecture/reference-architectures/hybrid-networking/hub-spoke)
- [Azure Firewall Documentation](https://docs.microsoft.com/azure/firewall/)
- [Private DNS Resolver](https://docs.microsoft.com/azure/dns/dns-private-resolver-overview)
- [Azure Policy](https://docs.microsoft.com/azure/governance/policy/)

