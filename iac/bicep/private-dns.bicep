/*
  NileRetail Group — Private DNS Zones for Private Link
  -------------------------------------------------------
  Deploys:
  - privatelink.azurewebsites.net      (App Service Private Endpoints)
  - privatelink.database.windows.net   (Azure SQL Private Endpoints)
  - VNet links for each zone to all VNets provided (Hub + Spoke-A + Spoke-B)

  Deploy this module to the hub resource group. Link to all VNets so that
  Private Endpoint DNS records are resolvable from every spoke.

  DNS Zone Groups (on each Private Endpoint) auto-create the A records
  in these zones — never create A records manually.
*/

targetScope = 'resourceGroup'

@description('Workload short name (e.g. ecom).')
param workload string = 'ecom'

@allowed(['prd', 'dev', 'tst'])
@description('Deployment environment.')
param environment string = 'prd'

@description('Array of VNet resource IDs to link to both Private DNS zones (Hub + all Spokes).')
param vnetIds array

@description('Additional tags merged with the default tag set.')
param additionalTags object = {}

// ─────────────────────────────────────────────────────────────────────────────
// Variables
// ─────────────────────────────────────────────────────────────────────────────

// FIX — vnetLinkNamePrefix was a param default that interpolated other params.
// Bicep does not allow param defaults to reference other params.
// Moved to a var, which can freely reference params.
var vnetLinkNamePrefix = 'vnetlink-${workload}-${environment}'

var defaultTags = {
  project: 'NileRetail'
  workload: workload
  environment: environment
  managedBy: 'bicep'
}
var tags = union(defaultTags, additionalTags)

var zoneWebsites = 'privatelink.azurewebsites.net'
var zoneSql      = 'privatelink.database.windows.net'

// ─────────────────────────────────────────────────────────────────────────────
// Private DNS Zones
// ─────────────────────────────────────────────────────────────────────────────

resource pdnsWebsites 'Microsoft.Network/privateDnsZones@2024-05-01' = {
  name: zoneWebsites
  location: 'global'
  tags: tags
}

resource pdnsSql 'Microsoft.Network/privateDnsZones@2024-05-01' = {
  name: zoneSql
  location: 'global'
  tags: tags
}

// ─────────────────────────────────────────────────────────────────────────────
// VNet Links
// Link each zone to every VNet in the vnetIds array (Hub + all Spokes).
// registrationEnabled: false — these zones are for Private Endpoints only,
// not for auto-registering VM DNS names.
// ─────────────────────────────────────────────────────────────────────────────

resource websitesLinks 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-05-01' = [for vnetId in vnetIds: {
  parent: pdnsWebsites
  // uniqueString suffix prevents name collisions when VNet IDs differ only by region.
  name: '${vnetLinkNamePrefix}-azweb-${toLower(take(uniqueString(vnetId), 6))}'
  location: 'global'
  properties: {
    virtualNetwork: { id: vnetId }
    registrationEnabled: false
  }
}]

resource sqlLinks 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-05-01' = [for vnetId in vnetIds: {
  parent: pdnsSql
  name: '${vnetLinkNamePrefix}-sql-${toLower(take(uniqueString(vnetId), 6))}'
  location: 'global'
  properties: {
    virtualNetwork: { id: vnetId }
    registrationEnabled: false
  }
}]

// ─────────────────────────────────────────────────────────────────────────────
// Outputs
// ─────────────────────────────────────────────────────────────────────────────

@description('Resource ID of privatelink.azurewebsites.net zone. Pass to App Service PE DNS zone group.')
output privateDnsWebsitesZoneId string = pdnsWebsites.id

@description('Resource ID of privatelink.database.windows.net zone. Pass to SQL PE DNS zone group.')
output privateDnsSqlZoneId string = pdnsSql.id
