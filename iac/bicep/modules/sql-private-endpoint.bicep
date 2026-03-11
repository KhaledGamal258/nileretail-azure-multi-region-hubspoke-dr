// Deploy a Private Endpoint for an Azure SQL server + attach a DNS Zone Group.
// This module is used with a different resource-group scope for the secondary region.

targetScope = 'resourceGroup'

@description('Azure region for the private endpoint (should match the VNet location).')
param location string

@description('Private Endpoint resource name (e.g., pep-sql-ecom-prd-weu-01).')
param privateEndpointName string

@description('Subnet resource ID where the Private Endpoint will be deployed (snet-pe).')
param subnetId string

@description('Resource ID of the Azure SQL server to connect to.')
param sqlServerId string

@description('Resource ID of the privatelink.database.windows.net Private DNS zone.')
param privateDnsZoneId string

@description('Tags to apply to the Private Endpoint resource.')
param tags object

resource pe 'Microsoft.Network/privateEndpoints@2023-09-01' = {
  name: privateEndpointName
  location: location
  tags: tags
  properties: {
    subnet: {
      id: subnetId
    }
    privateLinkServiceConnections: [
      {
        name: 'sqlServer'
        properties: {
          privateLinkServiceId: sqlServerId
          groupIds: [
            'sqlServer'
          ]
        }
      }
    ]
  }
}

// DNS Zone Group ensures correct A-records are created/managed automatically.
// Never create A-records manually for Private Endpoints.
resource peZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-09-01' = {
  parent: pe
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'sql'
        properties: {
          privateDnsZoneId: privateDnsZoneId
        }
      }
    ]
  }
}

@description('Resource ID of the Private Endpoint.')
output privateEndpointId string = pe.id
