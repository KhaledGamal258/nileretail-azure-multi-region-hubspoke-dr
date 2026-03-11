// Deploy a single Azure SQL logical server.
// Used by the parent sql-failover-group.bicep module to create the secondary server
// in a different resource group (Spoke-B).

targetScope = 'resourceGroup'

@description('Azure region for the SQL server (e.g., westeurope).')
param location string

@description('SQL server name following naming convention (e.g., sqlsrv-ecom-prd-weu-01).')
param serverName string

@description('SQL admin login name (do not use "sa").')
param sqlAdminLogin string

@description('SQL admin password (secure).')
@secure()
param sqlAdminPassword string

@description('Tags to apply to the SQL server resource.')
param tags object

resource sql 'Microsoft.Sql/servers@2023-08-01-preview' = {
  name: serverName
  location: location
  tags: tags
  properties: {
    version: '12.0'
    administratorLogin: sqlAdminLogin
    administratorLoginPassword: sqlAdminPassword
    publicNetworkAccess: 'Disabled'
    minimalTlsVersion: '1.2'
  }
}

@description('Resource ID of the SQL logical server.')
output serverId string = sql.id

@description('Name of the SQL logical server.')
output serverNameOut string = sql.name
