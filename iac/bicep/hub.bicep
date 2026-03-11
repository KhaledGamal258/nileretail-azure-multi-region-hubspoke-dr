/*
  NileRetail Group — Hub (UK South)
  ----------------------------------
  Deploys the Hub networking foundation for the multi-region Hub & Spoke design.

  What this module creates:
  - Hub VNet in UK South (10.10.0.0/16)
  - Subnets: GatewaySubnet, snet-pe, snet-dns
  - One VPN Gateway (Azure allows only one per VNet)
  - Optional Active-Active mode (recommended for production)

  VPN reality — important:
  - Azure VNet-to-VNet VPN requires a Connection resource on BOTH gateways (hub AND spoke).
  - This module only deploys the hub gateway.
  - Deploy spoke.bicep to create spoke gateways, then vnet2vnet-connection.bicep
    (twice per pair: once in hub RG, once in spoke RG) with the same shared key.
  - See docs/08-implementation-guide.md Phase 3 for the step-by-step order.
*/

targetScope = 'resourceGroup'

// ─────────────────────────────────────────────────────────────────────────────
// Parameters
// ─────────────────────────────────────────────────────────────────────────────

@description('Azure region for hub resources.')
param location string = resourceGroup().location

@allowed(['dev', 'tst', 'prd'])
@description('Deployment environment.')
param env string = 'prd'

@description('Workload short name used in resource naming (e.g. ecom).')
param workload string = 'ecom'

@description('Hub VNet name.')
param hubVnetName string = 'vnet-hub-uks-${env}'

@description('Hub VNet address space.')
param hubAddressPrefix string = '10.10.0.0/16'

// Subnet sizing guidance:
// - GatewaySubnet: /27 fits current requirement; use /26 if ExpressRoute co-existence is planned.
// - snet-pe: /24 — size for expected number of Private Endpoints plus headroom.
// - snet-dns: /28 minimum for DNS Private Resolver; /27 recommended.
@description('GatewaySubnet prefix. Must be named exactly GatewaySubnet (Azure requirement).')
param gatewaySubnetPrefix string = '10.10.0.0/27'

@description('Private Endpoint subnet prefix.')
param privateEndpointSubnetPrefix string = '10.10.1.0/24'

@description('DNS subnet prefix (for Azure DNS Private Resolver if added later).')
param dnsSubnetPrefix string = '10.10.2.0/24'

@description('VPN Gateway SKU. VpnGw1=650 Mbps aggregate; upsize for production traffic.')
@allowed(['VpnGw1', 'VpnGw2', 'VpnGw3', 'VpnGw1AZ', 'VpnGw2AZ', 'VpnGw3AZ'])
param vpnGwSkuName string = 'VpnGw1'

@description('Gateway generation. Generation2 is required for VpnGw2+ and preferred for new deployments.')
@allowed(['Generation1', 'Generation2'])
param vpnGwGeneration string = 'Generation2'

@description('''
Enable Active-Active mode (two public IPs, gateway HA without failover window).
Strongly recommended for production. Works with any SKU; pair with zone-redundant
SKUs (VpnGw*AZ) for full zonal HA.
''')
param activeActive bool = false

@description('Additional tags merged with the default tag set. Caller values win on key conflicts.')
param additionalTags object = {}

// ─────────────────────────────────────────────────────────────────────────────
// Variables
// ─────────────────────────────────────────────────────────────────────────────

// FIX #1 — Tags must be a var, NOT a param default.
// Bicep does not allow a param default value to reference other params.
// Declaring tags as a var (which CAN reference params) fixes the compilation error.
var defaultTags = {
  project: 'NileRetail'
  workload: workload
  environment: env
  architecture: 'hub-spoke-vpn'
  managedBy: 'bicep'
}
var tags = union(defaultTags, additionalTags)

var gatewayName = 'vpngw-${workload}-${env}-uks-01'
var pip1Name    = 'pip-vpngw-${workload}-${env}-uks-01'
var pip2Name    = 'pip-vpngw-${workload}-${env}-uks-02'

// FIX #2 — Build ipConfigurations with concat(), not union().
// union() on arrays deduplicates by value — semantically wrong for appending
// a second ipConfig object. concat() is explicit and correct for array append.
var ipConfig1 = [
  {
    name: 'vpngw-ipconfig-01'
    properties: {
      privateIPAllocationMethod: 'Dynamic'
      publicIPAddress: { id: pipVpngw1.id }
      subnet: {
        id: resourceId('Microsoft.Network/virtualNetworks/subnets', hubVnetName, 'GatewaySubnet')
      }
    }
  }
]

var ipConfig2 = activeActive ? [
  {
    name: 'vpngw-ipconfig-02'
    properties: {
      privateIPAllocationMethod: 'Dynamic'
      publicIPAddress: { id: pipVpngw2.id }
      subnet: {
        id: resourceId('Microsoft.Network/virtualNetworks/subnets', hubVnetName, 'GatewaySubnet')
      }
    }
  }
] : []

// ─────────────────────────────────────────────────────────────────────────────
// Hub VNet + Subnets
// ─────────────────────────────────────────────────────────────────────────────

resource hubVnet 'Microsoft.Network/virtualNetworks@2023-09-01' = {
  name: hubVnetName
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [hubAddressPrefix]
    }
    subnets: [
      {
        // Azure requires the VPN Gateway subnet to be named exactly 'GatewaySubnet'.
        // Do NOT attach an NSG or UDR to this subnet — Azure will reject the deployment.
        name: 'GatewaySubnet'
        properties: {
          addressPrefix: gatewaySubnetPrefix
        }
      }
      {
        name: 'snet-pe'
        properties: {
          addressPrefix: privateEndpointSubnetPrefix
          // 'Disabled' = legacy mode: NSGs are NOT enforced on Private Endpoints in this subnet.
          // For new deployments you can use 'Enabled' (NSGs + UDRs enforced) once you
          // have explicit NSG rules for PE traffic. Kept 'Disabled' here for compatibility.
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
      }
      {
        // Reserved for Azure DNS Private Resolver inbound/outbound endpoints.
        // Requires delegation to Microsoft.Network/dnsResolvers; minimum /28.
        name: 'snet-dns'
        properties: {
          addressPrefix: dnsSubnetPrefix
        }
      }
    ]
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Public IPs for VPN Gateway
// ─────────────────────────────────────────────────────────────────────────────

resource pipVpngw1 'Microsoft.Network/publicIPAddresses@2023-09-01' = {
  name: pip1Name
  location: location
  tags: tags
  sku: { name: 'Standard' }
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
  }
}

resource pipVpngw2 'Microsoft.Network/publicIPAddresses@2023-09-01' = if (activeActive) {
  name: pip2Name
  location: location
  tags: tags
  sku: { name: 'Standard' }
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Hub VPN Gateway
// ─────────────────────────────────────────────────────────────────────────────

resource vpngwHub 'Microsoft.Network/virtualNetworkGateways@2023-09-01' = {
  name: gatewayName
  location: location
  tags: tags
  dependsOn: [hubVnet]
  properties: {
    gatewayType: 'Vpn'
    vpnType: 'RouteBased'
    enableBgp: false
    activeActive: activeActive
    vpnGatewayGeneration: vpnGwGeneration
    sku: {
      name: vpnGwSkuName
      tier: vpnGwSkuName
    }
    ipConfigurations: concat(ipConfig1, ipConfig2)
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Outputs — consumed by spoke and connection deployments
// ─────────────────────────────────────────────────────────────────────────────

@description('Hub VNet resource ID.')
output hubVnetId string = hubVnet.id

@description('Hub VPN Gateway resource ID. Pass to vnet2vnet-connection.bicep.')
output hubGatewayId string = vpngwHub.id

@description('Hub VPN Gateway primary public IP address.')
output hubGatewayPublicIp1 string = pipVpngw1.properties.ipAddress

@description('Hub VPN Gateway secondary public IP (empty string when activeActive = false).')
output hubGatewayPublicIp2 string = activeActive ? pipVpngw2.properties.ipAddress : ''

@description('GatewaySubnet resource ID.')
output hubGatewaySubnetId string = resourceId(
  'Microsoft.Network/virtualNetworks/subnets', hubVnet.name, 'GatewaySubnet'
)

@description('Private Endpoint subnet resource ID.')
output hubPrivateEndpointSubnetId string = resourceId(
  'Microsoft.Network/virtualNetworks/subnets', hubVnet.name, 'snet-pe'
)

@description('DNS subnet resource ID.')
output hubDnsSubnetId string = resourceId(
  'Microsoft.Network/virtualNetworks/subnets', hubVnet.name, 'snet-dns'
)
