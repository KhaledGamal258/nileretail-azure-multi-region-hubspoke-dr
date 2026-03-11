// ============================================================================
// NileRetail Group — Azure SQL Auto-Failover Group (Multi-region Production + DR)
//
// IMPORTANT:
// Apps MUST connect using the Failover Group listener FQDN, not the individual
// server FQDNs. Otherwise, failover breaks your app.
//
// ✅ Correct connection string (listener):
//   Server=tcp:fog-ecom-prd-01.database.windows.net,1433;Database=appdb;...
//
// ❌ Wrong (pins you to one region):
//   Server=tcp:sqlsrv-ecom-prd-neu-01.database.windows.net,1433;Database=appdb;...
// ============================================================================

targetScope = 'resourceGroup'

@description('Primary SQL region (e.g., northeurope).')
param primaryLocation string

@description('Secondary SQL region (e.g., westeurope).')
param secondaryLocation string

@description('Environment name used in naming (e.g., prd, dev).')
@allowed([
  'prd'
  'dev'
  'tst'
])
param env string

@description('Workload name used in naming (e.g., ecom).')
param workload string

@description('SQL admin login name (do not use "sa").')
param sqlAdminLogin string

@description('SQL admin password (secure).')
@secure()
param sqlAdminPassword string

@description('Application database name (created on the primary server).')
param databaseName string

@description('SQL Database SKU name (e.g., GP_S_Gen5_2, S0, P1v3).')
param databaseSkuName string

@description('Failover policy for the Failover Group. Automatic triggers failover automatically after grace period; Manual requires explicit failover.')
@allowed([
  'Automatic'
  'Manual'
])
param failoverPolicy string = 'Manual'

@description('Grace period (minutes) for Automatic failover with data loss. Used only when failoverPolicy=Automatic.')
param gracePeriodMinutes int = 60

@description('Resource ID of the privatelink.database.windows.net Private DNS zone (typically hosted in the Hub RG).')
param privateDnsSqlZoneId string

@description('Subnet resource ID where the PRIMARY SQL Private Endpoint will be placed (typically snet-pe in Spoke-A).')
param primaryPeSubnetId string

@description('Subnet resource ID where the SECONDARY SQL Private Endpoint will be placed (typically snet-pe in Spoke-B).')
param secondaryPeSubnetId string

@description('Name of the resource group that hosts the secondary SQL server (Spoke-B RG).')
param secondaryResourceGroupName string

@description('Additional tags to merge into the default tags.')
param additionalTags object = {}

// -------------------------------
// Tags
// -------------------------------
var defaultTags = {
  project: 'NileRetail'
  workload: workload
  environment: env
  component: 'sql'
}

var tags = union(defaultTags, additionalTags)

// -------------------------------
// Naming helpers
// -------------------------------
var locationToCode = {
  northeurope: 'neu'
  westeurope: 'weu'
  uksouth: 'uks'
  ukwest: 'ukw'
}

var primaryRegionCode = locationToCode[primaryLocation]
var secondaryRegionCode = locationToCode[secondaryLocation]

// Naming convention: <rtype>-<workload>-<env>-<region>-<nn>
var primaryServerName = 'sqlsrv-${workload}-${env}-${primaryRegionCode}-01'
var secondaryServerName = 'sqlsrv-${workload}-${env}-${secondaryRegionCode}-01'
var fogName = 'fog-${workload}-${env}-01'

var primaryPeName = 'pep-sql-${workload}-${env}-${primaryRegionCode}-01'
var secondaryPeName = 'pep-sql-${workload}-${env}-${secondaryRegionCode}-01'

// -------------------------------
// Primary SQL server (this RG)
// -------------------------------
resource primarySql 'Microsoft.Sql/servers@2023-08-01-preview' = {
  name: primaryServerName
  location: primaryLocation
  tags: tags
  properties: {
    version: '12.0'
    administratorLogin: sqlAdminLogin
    administratorLoginPassword: sqlAdminPassword
    publicNetworkAccess: 'Disabled'
    minimalTlsVersion: '1.2'
  }
}

// Primary database (replication is configured via Failover Group)
// FIX: In Bicep, child resources must use `parent:`. Slash-delimited names are ARM JSON notation and cause compilation errors in Bicep.
resource primaryDb 'Microsoft.Sql/servers/databases@2023-08-01-preview' = {
  parent: primarySql
  name: databaseName
  location: primaryLocation
  tags: tags
  sku: {
    name: databaseSkuName
  }
  properties: {
    // Use defaults; tune per workload.
    readScale: 'Disabled'
  }
}

// -------------------------------
// Secondary SQL server (secondary RG)
// NOTE: This file is RG-scoped, so we deploy the secondary server using a module
// with a different scope.
// -------------------------------
module secondarySql 'modules/sql-server.bicep' = {
  name: 'dep-secondary-sql-${secondaryRegionCode}-${env}-01'
  scope: resourceGroup(secondaryResourceGroupName)
  params: {
    location: secondaryLocation
    serverName: secondaryServerName
    sqlAdminLogin: sqlAdminLogin
    sqlAdminPassword: sqlAdminPassword
    tags: tags
  }
}

// -------------------------------
// Failover Group (created on primary server)
// -------------------------------
// FIX: In Bicep, child resources must use `parent:`. Slash-delimited names are ARM JSON notation and cause compilation errors in Bicep.
resource failoverGroup 'Microsoft.Sql/servers/failoverGroups@2023-08-01-preview' = {
  parent: primarySql
  name: fogName
  tags: tags
  properties: {
    readWriteEndpoint: {
      failoverPolicy: failoverPolicy
      // Grace period is only valid for Automatic.
      failoverWithDataLossGracePeriodMinutes: failoverPolicy == 'Automatic' ? gracePeriodMinutes : null
    }
    // Enable the read-only listener endpoint (*.secondary.database.windows.net)
    // Useful for read-only traffic (reporting, analytics).
    readOnlyEndpoint: {
      failoverPolicy: 'Enabled'
    }
    partnerServers: [
      {
        id: secondarySql.outputs.serverId
      }
    ]
    databases: [
      primaryDb.id
    ]
  }
}

// -------------------------------
// Private Endpoint (Primary) + DNS Zone Group
// Never create private DNS A records manually. DNS Zone Groups ensure the right
// records exist and stay updated if IPs change.
// -------------------------------
resource primaryPe 'Microsoft.Network/privateEndpoints@2023-09-01' = {
  name: primaryPeName
  location: primaryLocation
  tags: tags
  properties: {
    subnet: {
      id: primaryPeSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: 'sqlServer'
        properties: {
          privateLinkServiceId: primarySql.id
          groupIds: [
            'sqlServer'
          ]
        }
      }
    ]
  }
}

resource primaryPeZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-09-01' = {
  parent: primaryPe
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'sql'
        properties: {
          privateDnsZoneId: privateDnsSqlZoneId
        }
      }
    ]
  }
}

// -------------------------------
// Private Endpoint (Secondary) + DNS Zone Group (secondary RG)
// -------------------------------
module secondaryPe 'modules/sql-private-endpoint.bicep' = {
  name: 'dep-secondary-sql-pe-${secondaryRegionCode}-${env}-01'
  scope: resourceGroup(secondaryResourceGroupName)
  params: {
    location: secondaryLocation
    privateEndpointName: secondaryPeName
    subnetId: secondaryPeSubnetId
    sqlServerId: secondarySql.outputs.serverId
    privateDnsZoneId: privateDnsSqlZoneId
    tags: tags
  }
}

// -------------------------------
// Outputs
// -------------------------------
@description('Failover Group read-write listener FQDN. Use this in application connection strings.')
output failoverGroupListenerFqdn string = '${fogName}.database.windows.net'

@description('Failover Group read-only listener FQDN (enabled in this module).')
output failoverGroupReadOnlyFqdn string = '${fogName}.secondary.database.windows.net'

@description('Resource ID of the primary SQL logical server.')
output primaryServerId string = primarySql.id

@description('Resource ID of the failover group.')
output failoverGroupId string = failoverGroup.id
