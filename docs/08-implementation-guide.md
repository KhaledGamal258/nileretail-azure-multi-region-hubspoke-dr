# Implementation guide

This guide is **hands-on**: copy-paste friendly Azure CLI commands with verification checkpoints after each phase.

> **Naming convention** used everywhere: `<rtype>-<workload>-<env>-<region>-<nn>`
>
> Examples: `vnet-hub-uks-prd` · `agw-ecom-prd-neu-01` · `vpngw-ecom-prd-uks-01`

---

## Regions

| Layer    | Region        | Code  | Address space   |
|----------|---------------|-------|-----------------|
| Hub      | UK South      | `uks` | `10.10.0.0/16`  |
| Spoke-A  | North Europe  | `neu` | `10.11.0.0/16`  |
| Spoke-B  | West Europe   | `weu` | `10.12.0.0/16`  |

---

## Phase 0 — Prerequisites (one-time)

```bash
az login
az account set --subscription "<SUBSCRIPTION_NAME_OR_ID>"

# Capture subscription ID — used to build resource IDs in Phase 3.
SUB=$(az account show --query id -o tsv)
echo "SUB=$SUB"

# Register required providers (safe to run even if already registered).
az provider register --namespace Microsoft.Network --wait
az provider register --namespace Microsoft.Web    --wait
az provider register --namespace Microsoft.Sql    --wait
```

---

## Phase 1 — Hub Build (UK South)

### 1. Create the resource group

```bash
az group create --name rg-ecom-prd-uks-hub --location uksouth
```

### 2. Deploy Hub VNet + subnets + VPN Gateway (Bicep)

The hub module creates:
- VNet `vnet-hub-uks-prd` (`10.10.0.0/16`)
- Subnets: `GatewaySubnet`, `snet-pe`, `snet-dns`
- VPN Gateway `vpngw-ecom-prd-uks-01` (RouteBased, Generation2)

```bash
az deployment group create \
  --resource-group rg-ecom-prd-uks-hub \
  --name dep-hub-prd-uks-01 \
  --template-file iac/bicep/hub.bicep \
  --parameters env=prd workload=ecom location=uksouth
```

### 3. Verify hub gateway provisioning

```bash
az network vnet show \
  -g rg-ecom-prd-uks-hub -n vnet-hub-uks-prd \
  --query "addressSpace.addressPrefixes" -o tsv

az network vnet-gateway show \
  -g rg-ecom-prd-uks-hub -n vpngw-ecom-prd-uks-01 \
  --query provisioningState -o tsv
```

✅ Expected: `Succeeded`

> VPN Gateways take 30–45 minutes. Use `--no-wait` and continue to Phase 2 in parallel.

---

## Phase 2 — Spoke Build (North Europe + West Europe)

Each spoke uses these subnets (aligned with `docs/01-network-design.md`):

| Subnet              | Size  | Purpose                                           |
|---------------------|-------|---------------------------------------------------|
| `snet-appgw`        | `/24` | Application Gateway v2 (dedicated, no sharing)   |
| `snet-appsvc-int`   | `/24` | App Service VNet Integration (delegated to Web)   |
| `snet-pe`           | `/24` | Private Endpoints                                  |
| `GatewaySubnet`     | `/27` | VPN Gateway (exact name required)                 |

### Option A — Deploy spokes via Bicep (recommended)

```bash
# Spoke-A (North Europe)
az group create --name rg-ecom-prd-neu-spoke --location northeurope

az deployment group create \
  --resource-group rg-ecom-prd-neu-spoke \
  --name dep-spoke-prd-neu-01 \
  --template-file iac/bicep/spoke.bicep \
  --parameters \
    env=prd workload=ecom location=northeurope regionCode=neu \
    spokeAddressPrefix=10.11.0.0/16 \
    appGwSubnetPrefix=10.11.0.0/24 \
    appSvcIntSubnetPrefix=10.11.1.0/24 \
    privateEndpointSubnetPrefix=10.11.2.0/24 \
    gatewaySubnetPrefix=10.11.254.0/27

# Spoke-B (West Europe)
az group create --name rg-ecom-prd-weu-spoke --location westeurope

az deployment group create \
  --resource-group rg-ecom-prd-weu-spoke \
  --name dep-spoke-prd-weu-01 \
  --template-file iac/bicep/spoke.bicep \
  --parameters \
    env=prd workload=ecom location=westeurope regionCode=weu \
    spokeAddressPrefix=10.12.0.0/16 \
    appGwSubnetPrefix=10.12.0.0/24 \
    appSvcIntSubnetPrefix=10.12.1.0/24 \
    privateEndpointSubnetPrefix=10.12.2.0/24 \
    gatewaySubnetPrefix=10.12.254.0/27
```

### Option B — CLI (if you prefer granular control)

```bash
az group create --name rg-ecom-prd-neu-spoke --location northeurope

az network vnet create \
  -g rg-ecom-prd-neu-spoke -n vnet-ecom-prd-neu-01 -l northeurope \
  --address-prefixes 10.11.0.0/16 \
  --subnet-name snet-appgw --subnet-prefixes 10.11.0.0/24

# App Service integration subnet — delegation is MANDATORY.
# Without --delegations, az webapp vnet-integration add will fail.
az network vnet subnet create \
  -g rg-ecom-prd-neu-spoke --vnet-name vnet-ecom-prd-neu-01 \
  -n snet-appsvc-int --address-prefixes 10.11.1.0/24 \
  --delegations Microsoft.Web/serverFarms

# Private Endpoint subnet.
# Use --private-endpoint-network-policies (replaces the deprecated
# --disable-private-endpoint-network-policies flag).
az network vnet subnet create \
  -g rg-ecom-prd-neu-spoke --vnet-name vnet-ecom-prd-neu-01 \
  -n snet-pe --address-prefixes 10.11.2.0/24 \
  --private-endpoint-network-policies Disabled

# GatewaySubnet — exact name required by Azure.
az network vnet subnet create \
  -g rg-ecom-prd-neu-spoke --vnet-name vnet-ecom-prd-neu-01 \
  -n GatewaySubnet --address-prefixes 10.11.254.0/27
```

Repeat for Spoke-B using: RG = rg-ecom-prd-weu-spoke, VNet = vnet-ecom-prd-weu-01, address space = 10.12.0.0/16.

### Create spoke VPN gateways

```bash
# Spoke-A gateway (--no-wait so hub and both spokes provision in parallel)
az network public-ip create \
  -g rg-ecom-prd-neu-spoke -n pip-vpngw-ecom-prd-neu-01 -l northeurope \
  --sku Standard --allocation-method Static

az network vnet-gateway create \
  -g rg-ecom-prd-neu-spoke -n vpngw-ecom-prd-neu-01 -l northeurope \
  --public-ip-addresses pip-vpngw-ecom-prd-neu-01 \
  --vnet vnet-ecom-prd-neu-01 \
  --gateway-type Vpn --vpn-type RouteBased --sku VpnGw1 \
  --no-wait

# Spoke-B gateway
az network public-ip create \
  -g rg-ecom-prd-weu-spoke -n pip-vpngw-ecom-prd-weu-01 -l westeurope \
  --sku Standard --allocation-method Static

az network vnet-gateway create \
  -g rg-ecom-prd-weu-spoke -n vpngw-ecom-prd-weu-01 -l westeurope \
  --public-ip-addresses pip-vpngw-ecom-prd-weu-01 \
  --vnet vnet-ecom-prd-weu-01 \
  --gateway-type Vpn --vpn-type RouteBased --sku VpnGw1 \
  --no-wait
```

### Verify all gateways are ready before continuing

```bash
az network vnet-gateway show \
  -g rg-ecom-prd-uks-hub -n vpngw-ecom-prd-uks-01 \
  --query provisioningState -o tsv

az network vnet-gateway show \
  -g rg-ecom-prd-neu-spoke -n vpngw-ecom-prd-neu-01 \
  --query provisioningState -o tsv

az network vnet-gateway show \
  -g rg-ecom-prd-weu-spoke -n vpngw-ecom-prd-weu-01 \
  --query provisioningState -o tsv
```

✅ Expected: all three return `Succeeded` before moving to Phase 3.

---

## Phase 3 — VNet-to-VNet VPN Connections (BOTH sides, cross-RG)

> **Critical concept — VPN vs Peering:**
> VNet Peering is bidirectional with one resource.
> VNet-to-VNet VPN requires **a Connection resource on EACH gateway** with the same shared key.
> For each hub↔spoke pair you create **two** connection objects.

```bash
export VPN_PSK='Use-A-Long-Random-PSK-Here-Minimum-32-Characters'
```

**Why full resource IDs are required here:**
`az network vpn-connection create --vnet-gateway2` only accepts a gateway *name* if the
remote gateway is in the **same resource group** as `-g`. Since the hub and spokes live
in different RGs, you must supply the full resource ID — otherwise the CLI fails silently.

```bash
# Build full resource IDs once
HUB_GW_ID="/subscriptions/${SUB}/resourceGroups/rg-ecom-prd-uks-hub/providers/Microsoft.Network/virtualNetworkGateways/vpngw-ecom-prd-uks-01"
NEU_GW_ID="/subscriptions/${SUB}/resourceGroups/rg-ecom-prd-neu-spoke/providers/Microsoft.Network/virtualNetworkGateways/vpngw-ecom-prd-neu-01"
WEU_GW_ID="/subscriptions/${SUB}/resourceGroups/rg-ecom-prd-weu-spoke/providers/Microsoft.Network/virtualNetworkGateways/vpngw-ecom-prd-weu-01"
```

### Hub ↔ Spoke-A (2 connection objects)

```bash
# 1 of 2 — Hub side (deployed to hub RG)
az network vpn-connection create \
  -g rg-ecom-prd-uks-hub \
  -n conn-ecom-prd-uks-to-neu-01 \
  --vnet-gateway1 "$HUB_GW_ID" \
  --vnet-gateway2 "$NEU_GW_ID" \
  --shared-key "$VPN_PSK"

# 2 of 2 — Spoke-A side (deployed to spoke RG, same shared key)
az network vpn-connection create \
  -g rg-ecom-prd-neu-spoke \
  -n conn-ecom-prd-neu-to-uks-01 \
  --vnet-gateway1 "$NEU_GW_ID" \
  --vnet-gateway2 "$HUB_GW_ID" \
  --shared-key "$VPN_PSK"
```

### Hub ↔ Spoke-B (2 connection objects)

```bash
# 1 of 2 — Hub side
az network vpn-connection create \
  -g rg-ecom-prd-uks-hub \
  -n conn-ecom-prd-uks-to-weu-01 \
  --vnet-gateway1 "$HUB_GW_ID" \
  --vnet-gateway2 "$WEU_GW_ID" \
  --shared-key "$VPN_PSK"

# 2 of 2 — Spoke-B side
az network vpn-connection create \
  -g rg-ecom-prd-weu-spoke \
  -n conn-ecom-prd-weu-to-uks-01 \
  --vnet-gateway1 "$WEU_GW_ID" \
  --vnet-gateway2 "$HUB_GW_ID" \
  --shared-key "$VPN_PSK"
```

### Verify connection status

```bash
az network vpn-connection show \
  -g rg-ecom-prd-uks-hub -n conn-ecom-prd-uks-to-neu-01 \
  --query connectionStatus -o tsv

az network vpn-connection show \
  -g rg-ecom-prd-uks-hub -n conn-ecom-prd-uks-to-weu-01 \
  --query connectionStatus -o tsv
```

✅ Expected: `Connected`

---

## Phase 4 — Private DNS Zones (centralised in hub)

```bash
# Capture VNet resource IDs
HUB_VNET_ID=$(az network vnet show \
  -g rg-ecom-prd-uks-hub -n vnet-hub-uks-prd --query id -o tsv)

NEU_VNET_ID=$(az network vnet show \
  -g rg-ecom-prd-neu-spoke -n vnet-ecom-prd-neu-01 --query id -o tsv)

WEU_VNET_ID=$(az network vnet show \
  -g rg-ecom-prd-weu-spoke -n vnet-ecom-prd-weu-01 --query id -o tsv)
```

Pass the array as a properly JSON-escaped parameter.
The IDs contain slashes and special characters and must be quoted as JSON strings.

```bash
az deployment group create \
  --resource-group rg-ecom-prd-uks-hub \
  --name dep-private-dns-prd-01 \
  --template-file iac/bicep/private-dns.bicep \
  --parameters \
    workload=ecom environment=prd \
    "vnetIds=[\"${HUB_VNET_ID}\",\"${NEU_VNET_ID}\",\"${WEU_VNET_ID}\"]"
```

✅ Verify: each Private DNS Zone has 3 VNet links (hub + neu + weu).

```bash
az network private-dns link vnet list \
  -g rg-ecom-prd-uks-hub -z privatelink.database.windows.net \
  --query "[].{name:name,vnet:virtualNetwork.id}" -o table
```

---

## Phase 5 — Validate DNS + Connectivity

From a VM inside one of the VNets (or via Kudu console of an App Service):

```bash
./scripts/validate-dns.sh
```

If DNS resolution fails, confirm:
- The Private DNS zone is linked to the VNet you're resolving from.
- Each Private Endpoint has a DNS Zone Group attached (not a manual A record).
- `snet-pe` has `privateEndpointNetworkPolicies: Disabled`.

---

## Next Steps

- Deploy App Gateway v2 in each spoke (`snet-appgw`). NSG on this subnet **must** allow
  inbound 65200-65535 from `GatewayManager` or AGW provisioning will fail.
- Deploy App Service Premium v3 with VNet Integration pointing to `snet-appsvc-int`.
- Set `WEBSITE_DNS_SERVER` app setting to your hub DNS resolver IP (or `168.63.129.16`
  if using direct zone links without a custom resolver).
- Set `WEBSITE_VNET_ROUTE_ALL=1` to route all App Service traffic through the VNet.
- Disable App Service and SQL public network access explicitly — Private Endpoints
  alone do NOT remove public access.
- Run `sql-failover-group.bicep` to deploy the SQL layer and failover group.
- Run `frontdoor-private-origin.bicep` then approve the PE connections on each AGW.
