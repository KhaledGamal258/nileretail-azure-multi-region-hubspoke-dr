/*
  VNet-to-VNet VPN Connection (one side)
  -------------------------------------
  Azure requires a connection resource on BOTH sides of a VNet-to-VNet VPN.

  Deploy this module twice for each hub↔spoke pair:
    1) In the hub RG:  local = hub gateway,  remote = spoke gateway
    2) In the spoke RG: local = spoke gateway, remote = hub gateway

  Shared key must match on both sides.
*/

targetScope = 'resourceGroup'

@description('Azure region for the connection resource (usually same as the local gateway location).')
param location string = resourceGroup().location

@description('Connection resource name following the project naming convention.')
param connectionName string

@description('Resource ID of the LOCAL Virtual Network Gateway.')
param localGatewayId string

@description('Resource ID of the REMOTE Virtual Network Gateway.')
param remoteGatewayId string

@secure()
@description('Pre-shared key (PSK). Must be identical on both sides.')
param sharedKey string

@description('Enable BGP (normally false for simple hub↔spoke VNet-to-VNet).')
param enableBgp bool = false

@description('Routing weight (rarely needed; keep default 10).')
param routingWeight int = 10

@description('Resource tags applied to the connection resource.')
param tags object = {}

resource vnet2vnetConn 'Microsoft.Network/connections@2023-09-01' = {
  name: connectionName
  location: location
  tags: tags
  properties: {
    connectionType: 'Vnet2Vnet'
    virtualNetworkGateway1: {
      id: localGatewayId
    }
    virtualNetworkGateway2: {
      id: remoteGatewayId
    }
    sharedKey: sharedKey
    enableBgp: enableBgp
    routingWeight: routingWeight
  }
}

output connectionId string = vnet2vnetConn.id
