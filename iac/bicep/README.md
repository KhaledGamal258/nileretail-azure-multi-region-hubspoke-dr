# Bicep modules

This folder contains the deployable Infrastructure-as-Code for the NileRetail Group multi-region platform. All modules are production-ready and follow the project naming convention: `<rtype>-<workload>-<env>-<region>-<nn>`.

---

## Module overview

| Module | Scope | What it deploys |
|--------|-------|-----------------|
| [`hub.bicep`](hub.bicep) | Resource Group | Hub VNet (UK South), GatewaySubnet + snet-pe + snet-dns, VPN Gateway (active-active capable), Public IPs |
| [`spoke.bicep`](spoke.bicep) | Resource Group | Spoke VNet (NEU or WEU), four subnets (snet-appgw, snet-appsvc-int with delegation, snet-pe, GatewaySubnet), Spoke VPN Gateway |
| [`vnet2vnet-connection.bicep`](vnet2vnet-connection.bicep) | Resource Group | One side of a VNet-to-VNet VPN connection — deploy twice per hub↔spoke pair (once in hub RG, once in spoke RG) with the same shared key |
| [`private-dns.bicep`](private-dns.bicep) | Resource Group | Private DNS zones (`privatelink.database.windows.net`, `privatelink.azurewebsites.net`) + VNet links to Hub + both Spokes |
| [`sql-failover-group.bicep`](sql-failover-group.bicep) | Resource Group | Primary SQL server (NEU), secondary SQL server (WEU via cross-RG module scope), database, Auto-Failover Group, Private Endpoints + DNS Zone Groups in both regions |
| [`frontdoor-private-origin.bicep`](frontdoor-private-origin.bicep) | Resource Group | Azure Front Door Premium profile + endpoint, WAF policy (Prevention mode, OWASP 2.1, Bot Manager 1.1), origin group with Private Link to both App Gateways, HTTPS-only route, security policy |

---

## Supporting modules (`modules/`)

| Module | Used by | What it does |
|--------|---------|--------------|
| [`modules/sql-server.bicep`](modules/sql-server.bicep) | `sql-failover-group.bicep` | Deploys a single SQL logical server — used to create the secondary server in a different resource group (cross-RG module scope) |
| [`modules/sql-private-endpoint.bicep`](modules/sql-private-endpoint.bicep) | `sql-failover-group.bicep` | Deploys a Private Endpoint + DNS Zone Group for a SQL server — used for the secondary PE in the secondary RG |

---

## Deployment order

Deploy in this order — each module depends on outputs from the previous ones:

```
1. hub.bicep              → outputs: hubVnetId, hubGatewayId, hubGatewayPublicIp1
2. spoke.bicep (×2)       → outputs: spokeVnetId, spokeGatewayId, appGwSubnetId, etc.
3. vnet2vnet-connection   → deploy TWICE per pair (hub RG + spoke RG, same shared key)
4. private-dns.bicep      → pass all three VNet IDs (hub + NEU + WEU)
5. sql-failover-group     → pass primary/secondary subnets + DNS zone ID from step 4
6. frontdoor-private-origin → pass App Gateway resource IDs from spoke deployments
```

See [`docs/08-implementation-guide.md`](../../docs/08-implementation-guide.md) for the full step-by-step CLI guide.

---

## Key design notes

- **`parent:` syntax** — all child resources use `parent:` (not slash-delimited names). Slash names are ARM JSON notation and cause Bicep compilation errors.
- **Cross-RG modules** — `sql-failover-group.bicep` deploys to two resource groups using `scope: resourceGroup(secondaryResourceGroupName)`. The caller must have Contributor access to both RGs.
- **VPN Connection resources** — Azure requires a Connection object on **both** gateway sides. Deploy `vnet2vnet-connection.bicep` twice per hub↔spoke pair with identical shared keys.
- **Private Link approval** — after deploying `frontdoor-private-origin.bicep`, manually approve the Private Link connection on each Application Gateway: Portal → App Gateway → Networking → Private endpoint connections → Approve.
- **GatewaySubnet** — never attach an NSG or UDR to this subnet. Azure rejects VPN Gateway deployments if either is present.
