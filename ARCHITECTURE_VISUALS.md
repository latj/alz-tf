# Azure Landing Zone - Visual Architecture Summary

This document provides visual representations of the implemented Azure Landing Zone architecture.

## Network Architecture Diagram

```
┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
┃                   AZURE CLOUD (Single Region)                    ┃
┃                                                                   ┃
┃  ┌──────────────────────────────────────────────────────────┐   ┃
┃  │                                                          │   ┃
┃  │              HUB VNET (10.0.0.0/16)                     │   ┃
┃  │                                                          │   ┃
┃  │  ┌────────────────────────────────────────────────┐    │   ┃
┃  │  │  AzureFirewallSubnet (10.0.0.0/24)            │    │   ┃
┃  │  │  ┌──────────────────────────────────────────┐ │    │   ┃
┃  │  │  │                                          │ │    │   ┃
┃  │  │  │  Azure Firewall (Standard)              │ │    │   ┃
┃  │  │  │  - Firewall Policy                      │ │    │   ┃
┃  │  │  │  - App Rules (Azure Services)           │ │    │   ┃
┃  │  │  │  - Network Rules (DNS, NTP)             │ │    │   ┃
┃  │  │  │                                          │ │    │   ┃
┃  │  │  └──────────────────────────────────────────┘ │    │   ┃
┃  │  └────────────────────────────────────────────────┘    │   ┃
┃  │                                                          │   ┃
┃  │  ┌────────────────────────────────────────────────┐    │   ┃
┃  │  │  DNS Inbound Endpoint (10.0.1.0/24)          │    │   ┃
┃  │  │  ← Receives queries from on-premises         │    │   ┃
┃  │  └────────────────────────────────────────────────┘    │   ┃
┃  │                                                          │   ┃
┃  │  ┌────────────────────────────────────────────────┐    │   ┃
┃  │  │  DNS Outbound Endpoint (10.0.2.0/24)         │    │   ┃
┃  │  │  → Forwards to Azure DNS (168.63.129.16)    │    │   ┃
┃  │  └────────────────────────────────────────────────┘    │   ┃
┃  │                                                          │   ┃
┃  │  ┌────────────────────────────────────────────────┐    │   ┃
┃  │  │  GatewaySubnet (10.0.3.0/24)                 │    │   ┃
┃  │  │  [VPN/ExpressRoute Gateway - Optional]      │    │   ┃
┃  │  └────────────────────────────────────────────────┘    │   ┃
┃  │                                                          │   ┃
┃  └──────────────────────────────────────────────────────────┘   ┃
┃                                                                   ┃
┃              ┌─────────────────────────────────┐                 ┃
┃              │ Private DNS Zones Linked        │                 ┃
┃              │ to All VNets:                   │                 ┃
┃              │ - blob.core.windows.net         │                 ┃
┃              │ - vaultcore.azure.net           │                 ┃
┃              │ - database.windows.net          │                 ┃
┃              │ - azurewebsites.net             │                 ┃
┃              │ ... (11 more)                   │                 ┃
┃              └─────────────────────────────────┘                 ┃
┃                          ▲                                        ┃
┃                          │ Peering                               ┃
┃                     ┌────┴────┬────────┐                         ┃
┃                     │         │        │                         ┃
┃  ┌──────────────┐  │  ┌───────────────────┐   ┌──────────────┐ ┃
┃  │ PROD SPOKE   │  │  │ NONPROD SPOKE    │   │ (Future S)   │ ┃
┃  │(10.1.0.0/16)│◄──┤  │ (10.2.0.0/16)   │   │              │ ┃
┃  │              │  │  │                  │   │              │ ┃
┃  │ App Subnet   │  │  │ App Subnet      │   │              │ ┃
┃  │ 10.1.0.0/20  │  │  │ 10.2.0.0/20    │   │              │ ┃
┃  │              │  │  │                  │   │              │ ┃
┃  │ Data Subnet  │  │  │ Data Subnet     │   │              │ ┃
┃  │ 10.1.16.0/20 │  │  │ 10.2.16.0/20   │   │              │ ┃
┃  │              │  │  │                  │   │              │ ┃
┃  │ Shared Subnet│  │  │ Shared Subnet   │   │              │ ┃
┃  │ 10.1.24.0/24 │  │  │ 10.2.24.0/24   │   │              │ ┃
┃  │              │  │  │                  │   │              │ ┃
┃  │ ┌──────────┐ │  │  │ ┌──────────┐   │   │ ┌──────────┐  │ ┃
┃  │ │Route: → │ │  │  │ │Route: → │   │   │ │Route: → │  │ ┃
┃  │ │FW IP    │ │  │  │ │FW IP    │   │   │ │FW IP    │  │ ┃
┃  │ │0.0.0.0/0│ │  │  │ │0.0.0.0/0│   │   │ │0.0.0.0/0│  │ ┃
┃  │ └──────────┘ │  │  │ └──────────┘   │   │ └──────────┘  │ ┃
┃  └──────────────┘  │  └───────────────────┘   └──────────────┘ ┃
┃                    │                                             ┃
┃                    └─ Transit: Firewall Processes Traffic       ┃
┃                                                                   ┃
┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
```

## Management Group Hierarchy

```
                    ┌─────────────────────┐
                    │     Tenant Root     │
                    └──────────┬──────────┘
                               │
                ┌──────────────┴──────────────┐
                │                             │
          ┌─────▼──────┐         ┌────────────▼────────┐
          │  Platform  │         │  Landing Zones      │
          │   mg-X     │         │  mg-X-landing-zones │
          └────────────┘         └──────────┬──────────┘
                │                           │
                │                ┌──────────┴──────────┐
                │                │                     │
                │          ┌─────▼──────┐      ┌─────▼──────┐
                │          │ Production │      │  NonProd   │
                │          │ mg-X-prod  │      │mg-X-nonprod│
                │          └────────────┘      └────────────┘
                │
       ┌────────▼────────┐
       │                 │
    Shared Services   (Future)
     Subscriptions


RBAC Hierarchy:
  Platform MG: Assign platform/infrastructure roles
  ├── Prod Landing Zone: Assign production workload roles
  └── NonProd Landing Zone: Assign dev/test roles
```

## Policy Assignment Flow

```
┌─────────────────────────────────────────────────────────┐
│         SUBSCRIPTION-LEVEL POLICIES (Enforced)          │
└─────────────────────────────────────────────────────────┘
           │
           ├─ Microsoft Cloud Security Benchmark (Audit)
           │  └─ Identifies gaps → Log to Log Analytics
           │
           ├─ Allowed Locations (Enforce)
           │  ├─ Resources: Only deploy in allowed regions
           │  └─ Resource Groups: Only in allowed regions
           │
           ├─ Required Tags (Enforce)
           │  ├─ Require "environment" tag on RGs
           │  └─ Require "team" tag on RGs
           │
           ├─ Tag Inheritance (DINE with Managed Identity)
           │  ├─ Copy "environment" from RG → Resources
           │  ├─ Copy "team" from RG → Resources
           │  └─ Role: "Tag Contributor" assigned
           │
           └─ Activity Log Diagnostics (DINE with Managed Identity)
              ├─ Create diagnostic setting automatically
              ├─ Stream to Log Analytics
              └─ Role: "Log Analytics Contributor" + "Monitoring Contributor"

Legend:
  DINE = Deploy-If-Not-Exists (automatic remediation)
  ✓ = Policy created
  → = Audit/Compliance stream
```

## Data Flow: Activity Log to Log Analytics

```
┌──────────────────────────────────────┐
│   Azure Resource Management           │
│   (Create, Update, Delete, etc.)      │
└────────────────┬─────────────────────┘
                 │
                 ▼
        ┌────────────────┐
        │  Activity Log  │ ◄─── Administrative
        │   (Subscription)       Security
        │                        Alerts
        └────────┬───────┘       Policy
                 │               ServiceHealth
                 │
                 ▼ (Policy-driven)
        ┌─────────────────────┐
        │ Log Analytics       │
        │ Workspace           │
        │                     │
        │ Tables:             │
        │ - AzureActivity     │
        │ - AzureDiagnostics  │
        │ - CommonSecurityLog │
        │ - SecurityEvent     │
        └────────┬────────────┘
                 │
        ┌────────┴────────────┐
        │                     │
        ▼                     ▼
    ┌───────────┐         ┌──────────┐
    │ Analytics │         │ Alerts & │
    │ Queries   │         │ Reports  │
    └───────────┘         └──────────┘
```

## Firewall Policy Rule Structure

```
┌─────────────────────────────────────────────┐
│    Azure Firewall Policy (fwp-X)            │
│                                             │
│ ┌─────────────────────────────────────────┐│
│ │ Rule Collection Group                   ││
│ │ Priority: 100 (DefaultOutboundRules)    ││
│ │                                         ││
│ │ ┌──────────────────────────────────────┐││
│ │ │ Application Rule Collection          │││
│ │ │ Name: AllowAzureServices             │││
│ │ │ Priority: 100                        │││
│ │ │ Action: Allow                        │││
│ │ │                                      │││
│ │ │ Rule: AllowAzureCloud                │││
│ │ │  - Protocols: HTTP, HTTPS            │││
│ │ │  - Source: *                         │││
│ │ │  - Destination FQDNs:                │││
│ │ │    • *.azure.com                     │││
│ │ │    • *.microsoft.com                 │││
│ │ │    • *.windows.net                   │││
│ │ └──────────────────────────────────────┘││
│ │                                         ││
│ │ ┌──────────────────────────────────────┐││
│ │ │ Network Rule Collection              │││
│ │ │ Name: AllowOutbound                  │││
│ │ │ Priority: 200                        │││
│ │ │ Action: Allow                        │││
│ │ │                                      │││
│ │ │ Rule 1: AllowNTP                     │││
│ │ │  - Protocol: UDP                     │││
│ │ │  - Port: 123                         │││
│ │ │  - Source: *                         │││
│ │ │  - Destination: *                    │││
│ │ │                                      │││
│ │ │ Rule 2: AllowDNS                     │││
│ │ │  - Protocol: UDP                     │││
│ │ │  - Port: 53                          │││
│ │ │  - Source: *                         │││
│ │ │  - Destination: *                    │││
│ │ └──────────────────────────────────────┘││
│ │                                         ││
│ └─────────────────────────────────────────┘│
│                                             │
│ Attached to:                                │
│ └─ azurerm_firewall "this"                 │
│    (sku_name: AZFW_VNet, tier: Standard)   │
│                                             │
└─────────────────────────────────────────────┘
```

## Private DNS Resolution Flow

```
User VM (10.1.x.x)
    │
    │ Query: storage.blob.core.windows.net
    │
    ▼
┌─────────────────────────────────┐
│ Private DNS Zone Link           │
│ (to privatelink.blob...)        │
│                                 │
│ Resolves to: Private Endpoint IP│
│ (within VNet range)             │
└────────────┬────────────────────┘
             │
             ▼ (if not found locally)
    ┌────────────────────────────┐
    │ DNS Inbound Endpoint       │
    │ (10.0.1.x)                 │
    │ [Can receive on-prem DNS]  │
    └────────┬───────────────────┘
             │
             ▼
    ┌────────────────────────────┐
    │ DNS Resolver               │
    │ Forwarding Ruleset         │
    └────────┬───────────────────┘
             │
             ▼
    ┌────────────────────────────┐
    │ DNS Outbound Endpoint      │
    │ (10.0.2.x)                 │
    └────────┬───────────────────┘
             │
             ▼
    ┌────────────────────────────┐
    │ Azure DNS (168.63.129.16)  │
    └────────┬───────────────────┘
             │
             ▼ (if still not found)
    ┌────────────────────────────┐
    │ Public DNS Resolution      │
    │ (8.8.8.8, 1.1.1.1, etc)   │
    └────────────────────────────┘
```

## Defender for Cloud Configuration

```
                    DEFENDER FOR CLOUD
                          │
        ┌─────────────────┴──────────────────┐
        │                                    │
    ┌───▼─────┐                          ┌──▼────┐
    │ PROD    │                          │ NONPROD
    │ Enabled │                          │ Enabled
    │         │                          │
    ├─ Servers (P2)   ✓                 ├─ Servers (Free)
    ├─ Databases      ✓                 ├─ Databases   (Free)
    ├─ Containers     ✓                 ├─ Containers  ✓
    ├─ Key Vault      ✓                 ├─ Key Vault   ✓
    ├─ Storage        ✓                 └─ Storage     (Free)
    └─ ARM            ✓

    Cost Impact:                         Cost Impact:
    ~$X/month (P2 for Servers)          Low (mainly Containers)

    Security Contact: security@company.com
    └─ Alerts via email
    └─ Recommendations for remediation
    └─ Compliance scoring
```

## Terraform Module Dependency Graph

```
                        Root Module
                    (main.tf, variables.tf)
                              │
            ┌─────────────────┼─────────────────┐
            │                 │                 │
            ▼                 ▼                 ▼
    ┌──────────────┐  ┌──────────────┐  ┌──────────────┐
    │  Monitoring  │  │  Networking  │  │   Policy     │
    │   (LAW)      │  │ (Hub/Spokes) │  │ (Governance) │
    └──────┬───────┘  └──────┬───────┘  └──────┬───────┘
           │                 │                 │
           │                 │    ┌────────────┘
           │                 │    │
           └─────────────────┼────┼──────────┐
                             │    │          │
                             ▼    ▼          ▼
                        ┌──────────────┐   ┌──────────────┐
                        │   Security   │   │  Management  │
                        │  (Defender)  │   │   Groups     │
                        └──────────────┘   └──────────────┘
                        (No cross-deps)    (Deployed
                                           separately)
```

## Cost Allocation via Tags

```
Resource Tagging Hierarchy:
    │
    └─ Resource Group
       │
       ├─ environment: prod
       ├─ team: platform
       ├─ CostCenter: Engineering
       │
       └─ [Policy Inherits to Resources]
          │
          ├─ Virtual Network
          │   ├─ environment: prod (inherited)
          │   ├─ team: platform (inherited)
          │   └─ [...all RG tags inherited]
          │
          ├─ Azure Firewall
          │   ├─ environment: prod (inherited)
          │   └─ team: platform (inherited)
          │
          └─ Log Analytics
              ├─ environment: prod (inherited)
              └─ team: platform (inherited)

Cost Analysis by Tag:
    environment=prod    → Platform costs
    team=platform       → Infrastructure team allocation
    CostCenter=...      → Finance tracking
```

## Deployment Sequence

```
Week 0: Preparation
  1. Validate prerequisites ──▶ scripts/validate-prerequisites.sh
  2. Update terraform.tfvars

Week 1: Foundation
  3. Deploy Management Groups ──▶ modules/management-groups (ONE-TIME)
  4. Bootstrap Terraform State ──▶ scripts/bootstrap-backend.sh
  5. Deploy Landing Zone ────▶ infra/terraform apply

Week 2: Verification
  6. Verify Hub VNet peering ──▶ az network vnet peering list
  7. Verify Firewall rules ────▶ az network firewall policy list
  8. Verify DNS zones ────────▶ az network private-dns zone list
  9. Verify Policies active ──▶ az policy assignment list

Week 3: Workload Deployment
  10. Deploy app in spoke ────▶ App Subnet (10.1.0.0/20)
  11. Deploy database ────────▶ Data Subnet (10.1.16.0/20)
  12. Create Private Endpoint ▶ Shared Subnet (10.1.24.0/24)
  13. Test connectivity ──────▶ Firewall routes traffic

Week 4+: Operations
  14. Monitor policies ───────▶ Log Analytics queries
  15. Review Firewall logs ───▶ Identify custom rules needed
  16. Adjust Defender levels ▶ Add more services if needed
```

## Connectivity Test Scenarios

```
Scenario 1: Spoke-to-Spoke (prod to nonprod)
    VM in Prod (10.1.x.x) ──▶ VM in NonProd (10.2.x.x)
    │
    ▼ Route table: 0.0.0.0/0 → Firewall
    │
    Firewall (10.0.0.13)
    ├─ Check: Source 10.1.x.x, Dest 10.2.x.x
    ├─ Rule: Allow Azure services (0.0.0.0/0)
    └─ Result: ✓ ALLOWED
    │
    └─▶ Connection established ✓

Scenario 2: Spoke-to-Azure Service (via Private Endpoint)
    App in Prod (10.1.x.x) ──▶ Storage (Private Endpoint in 10.1.24.x)
    │
    ▼ Query: storage.blob.core.windows.net
    │
    Private DNS Zone
    └─ Resolves to Private Endpoint IP (10.1.24.x)
    │
    └─▶ Connection via Private Endpoint ✓

Scenario 3: Hybrid (On-Premises to Spoke)
    On-Premises Host ──▶ DNS Inbound Endpoint (10.0.1.x)
    │
    ▼ Query forwarded to Azure DNS
    │
    Private DNS Zone
    └─ Resolves to Service IP within VNet
    │
    └─▶ Connection established (if firewall allows) ✓
```

---

This visual architecture reference complements the technical documentation. Use this to:
- Present architecture to stakeholders
- Understand data flows
- Plan modifications
- Debug connectivity issues
- Document the implementation

