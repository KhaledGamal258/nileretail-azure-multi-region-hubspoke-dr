/*
  NileRetail Group — Spoke (North Europe or West Europe)
  -------------------------------------------------------
  Deploys a single spoke networking stack. Use once for Spoke-A (NEU)
  and once for Spoke-B (WEU) with different parameter values.

  What this module creates:
  - Spoke VNet with four subnets following project naming convention
  - VPN Gateway (one per spoke, required for VNet-to-VNet connectivity)

  Subnet layout (aligned with docs/01-network-design.md):
  ┌──────────────────────┬───────────┬───────────────────────────────────────────────┐
  │ Subnet               │ Size      │ Notes                                         │
  ├──────────────────────┼───────────┼───────────────────────────────────────────────┤
  │ snet-appgw           │ /24       │ App Gateway v2 dedicated subnet (required).   │
  │                      │           │ Minimum /26 per Microsoft; /24 gives autoscale│
  │                      │           │ headroom. NO NSG or UDR restrictions apply to │
  │                      │           │ the infra ports 65200-65535 (GatewayManager). │
  ├──────────────────────┼───────────┼───────────────────────────────────────────────┤
  │ snet-appsvc-int      │ /24       │ App Service VNet Integration subnet.          │
  │                      │           │ Delegated to Microsoft.Web/serverFarms.        │
  │                      │           │ Each App Service instance uses 1 IP from here.│
  │                      │           │ /24 gives 251 IPs for autoscale + slots.      │
  ├──────────────────────┼───────────┼───────────────────────────────────────────────┤
  │ snet-pe              │ /24       │ Private Endpoints for SQL, App Service, etc.  │
  ├──────────────────────┼───────────┼───────────────────────────────────────────────┤
  │ GatewaySubnet        │ /27       │ Exact name required by Azure. No NSG/UDR.    │
  └──────────────────────┴───────────┴───────────────────────────────────────────────┘

  After deploying both spokes, deploy vnet2vnet-connection.bicep TWICE per spoke:
    - Hub RG:   localGatewayId = hub GW,   remoteGatewayId = spoke GW
    - Spoke RG: localGatewayId = spoke GW, remoteGatewayId = hub GW
*/

targetScope = 'resourceGroup'

// ─────────────────────────────────────────────────────────────────────────────
// Parameters
// ─────────────────────────────────────────────────────────────────────────────

@description('Azure region for this spoke (e.g. northeurope, westeurope).')
param location string = resourceGroup().location

@allowed(['dev', 'tst', 'prd'])
@description('Deployment environment.')
param env string = 'prd'

@description('Workload short name used in resource naming (e.g. ecom).')
param workload string = 'ecom'

@description('Region short code used in resource names (e.g. neu, weu).')
@allowed(['neu', 'weu'])
param regionCode string

@description('Spoke VNet address space. Must not overlap hub or other spokes.')
param spokeAddressPrefix string

// Individual subnet prefixes — defaults match the address plan in docs/01-network-design.md.
// Override when deploying Spoke-B to use the 10.12.x.x range.
@description('Application Gateway subnet prefix (/24 recommended).')
param appGwSubnetPrefix string

@description('App Service VNet Integration subnet prefix (/24 recommended).')
param appSvcIntSubnetPrefix string

@description('Private Endpoint subnet prefix (/24 recommended).')
param privateEndpointSubnetPrefix string

@description('GatewaySubnet prefix (/27 minimum).')
param gatewaySubnetPrefix string

@description('VPN Gateway SKU. Match the hub gateway SKU for consistent throughput.')
@allowed(['VpnGw1', 'VpnGw2', 'VpnGw3', 'VpnGw1AZ', 'VpnGw2AZ', 'VpnGw3AZ'])
param vpnGwSkuName string = 'VpnGw1'

@description('Gateway generation. Must match or be compatible with the hub gateway generation.')
@allowed(['Generation1', 'Generation2'])
param vpnGwGeneration string = 'Generation2'

@description('Additional tags merged with the default tag set.')
param additionalTags object = {}

// ─────────────────────────────────────────────────────────────────────────────
// Variables
// ─────────────────────────────────────────────────────────────────────────────

var defaultTags = {
  project: 'NileRetail'
  workload: workload
  environment: env
  region: regionCode
  architecture: 'hub-spoke-vpn'
  managedBy: 'bicep'
}
var tags = union(defaultTags, additionalTags)

// Naming convention: <rtype>-<workload>-<env>-<region>-<nn>
// Example: vnet-ecom-prd-neu-01
var spokeVnetName = 'vnet-${workload}-${env}-${regionCode}-01'
var gatewayName   = 'vpngw-${workload}-${env}-${regionCode}-01'
var pipName       = 'pip-vpngw-${workload}-${env}-${regionCode}-01'

// ─────────────────────────────────────────────────────────────────────────────
// Spoke VNet + Subnets
// ─────────────────────────────────────────────────────────────────────────────

resource spokeVnet 'Microsoft.Network/virtualNetworks@2023-09-01' = {
  name: spokeVnetName
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [spokeAddressPrefix]
    }
    subnets: [
      {
        // Application Gateway v2 requires a dedicated subnet.
        // IMPORTANT: The NSG on this subnet MUST allow inbound 65200-65535 from
        // GatewayManager service tag — without this, AGW health probes fail and
        // the gateway will not provision. See docs/checklists/nsg-rules.md.
        name: 'snet-appgw'
        properties: {
          addressPrefix: appGwSubnetPrefix
        }
      }
      {
        // App Service VNet Integration subnet.
        // Delegation to Microsoft.Web/serverFarms is MANDATORY.
        // Without it, az webapp vnet-integration add will fail.
        // This subnet cannot be shared with other resource types.
        name: 'snet-appsvc-int'
        properties: {
          addressPrefix: appSvcIntSubnetPrefix
          delegations: [
            {
              name: 'delegation-appservice'
              properties: {
                serviceName: 'Microsoft.Web/serverFarms'
              }
            }
          ]
        }
      }
      {
        // Private Endpoints for App Service, Azure SQL, etc.
        name: 'snet-pe'
        properties: {
          addressPrefix: privateEndpointSubnetPrefix
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
      }
      {
        // Azure requires this subnet to be named exactly 'GatewaySubnet'.
        // Do NOT attach NSGs or UDRs to this subnet.
        name: 'GatewaySubnet'
        properties: {
          addressPrefix: gatewaySubnetPrefix
        }
      }
    ]
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Public IP for Spoke VPN Gateway
// ─────────────────────────────────────────────────────────────────────────────

resource pipVpngw 'Microsoft.Network/publicIPAddresses@2023-09-01' = {
  name: pipName
  location: location
  tags: tags
  sku: { name: 'Standard' }
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Spoke VPN Gateway
// One gateway per VNet — Azure hard limit. This gateway handles the
// spoke side of the VNet-to-VNet connection to the hub.
// ─────────────────────────────────────────────────────────────────────────────

resource spokeVpnGateway 'Microsoft.Network/virtualNetworkGateways@2023-09-01' = {
  name: gatewayName
  location: location
  tags: tags
  dependsOn: [spokeVnet]
  properties: {
    gatewayType: 'Vpn'
    vpnType: 'RouteBased'
    enableBgp: false
    activeActive: false // Keep spoke gateways in active-standby for cost; hub carries the HA config.
    vpnGatewayGeneration: vpnGwGeneration
    sku: {
      name: vpnGwSkuName
      tier: vpnGwSkuName
    }
    ipConfigurations: [
      {
        name: 'vpngw-ipconfig-01'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: { id: pipVpngw.id }
          subnet: {
            id: resourceId('Microsoft.Network/virtualNetworks/subnets', spokeVnet.name, 'GatewaySubnet')
          }
        }
      }
    ]
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Outputs — consumed by vnet2vnet-connection.bicep deployments
// ─────────────────────────────────────────────────────────────────────────────

@description('Spoke VNet resource ID.')
output spokeVnetId string = spokeVnet.id

@description('Spoke VPN Gateway resource ID. Pass to vnet2vnet-connection.bicep.')
output spokeGatewayId string = spokeVpnGateway.id

@description('Spoke VPN Gateway public IP address.')
output spokeGatewayPublicIp string = pipVpngw.properties.ipAddress

@description('App Gateway subnet resource ID.')
output appGwSubnetId string = resourceId(
  'Microsoft.Network/virtualNetworks/subnets', spokeVnet.name, 'snet-appgw'
)

@description('App Service VNet Integration subnet resource ID.')
output appSvcIntSubnetId string = resourceId(
  'Microsoft.Network/virtualNetworks/subnets', spokeVnet.name, 'snet-appsvc-int'
)

@description('Private Endpoint subnet resource ID.')
output privateEndpointSubnetId string = resourceId(
  'Microsoft.Network/virtualNetworks/subnets', spokeVnet.name, 'snet-pe'
)
