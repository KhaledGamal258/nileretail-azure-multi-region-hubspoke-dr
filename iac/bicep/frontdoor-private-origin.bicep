// ============================================================================
// NileRetail Group — Azure Front Door Premium + WAF + Private Link Origins
//
// WARNING (REAL-WORLD GOTCHA):
// After deploying this module, you MUST manually approve the Private Link
// connection on EACH Application Gateway:
//   App Gateway → Networking → Private endpoint connections → Approve
//
// Without approval, origins remain Unhealthy and Front Door returns HTTP 503.
//
// Example automation (per AGW) once the PEC exists:
//   az network private-endpoint-connection approve \
//     --resource-group <spoke-rg> \
//     --resource-name <agw-name> \
//     --type Microsoft.Network/applicationGateways \
//     --name <private-endpoint-connection-name> \
//     --description "Approve AFD Private Link origin"
// ============================================================================

targetScope = 'resourceGroup'

@description('Environment name used in naming (e.g., prd, dev).')
@allowed([
  'prd'
  'dev'
  'tst'
])
param env string

@description('Workload name used in naming (e.g., ecom).')
param workload string

@description('Resource ID of the PRIMARY Application Gateway (Spoke-A / North Europe).')
param primaryAgwResourceId string

@description('Resource ID of the SECONDARY Application Gateway (Spoke-B / West Europe).')
param secondaryAgwResourceId string

@description('Additional tags to merge into the default tags.')
param additionalTags object = {}

// -------------------------------
// Tags
// -------------------------------
var defaultTags = {
  project: 'NileRetail'
  workload: workload
  environment: env
  component: 'edge'
}

var tags = union(defaultTags, additionalTags)

// Naming convention: <rtype>-<workload>-<env>-<region>-<nn>
var wafPolicyName = 'waf-${workload}-${env}-01'
var afdProfileName = 'afd-${workload}-${env}-01'
var afdEndpointName = 'ep-${workload}-${env}-01'
var originGroupName = 'og-${workload}-${env}-01'
var routeName = 'rt-${workload}-${env}-01'
var securityPolicyName = 'secpol-${workload}-${env}-01'

// Host header used by AFD when forwarding to the App Gateway origin.
// In real deployments you typically set this to your application domain
// (e.g., shop.nileretail.com) and configure matching TLS certs on App Gateway.
//
// We set enforceCertificateNameCheck=false on origins to avoid TLS CN mismatches
// for portfolio/demo environments.
var originHostHeader = '${workload}-${env}.internal'

// -------------------------------
// WAF Policy
// -------------------------------
resource wafPolicy 'Microsoft.Network/frontDoorWebApplicationFirewallPolicies@2024-02-01' = {
  name: wafPolicyName
  location: 'Global'
  tags: tags
  properties: {
    policySettings: {
      enabledState: 'Enabled'
      // Never use Detection mode in production. It logs threats but blocks nothing.
      mode: 'Prevention'
      requestBodyCheck: 'Enabled'
    }
    managedRules: {
      managedRuleSets: [
        {
          ruleSetType: 'DefaultRuleSet'
          ruleSetVersion: '2.1'
        }
        {
          ruleSetType: 'Microsoft_BotManagerRuleSet'
          ruleSetVersion: '1.1'
        }
      ]
    }
    sku: {
      name: 'Premium_AzureFrontDoor'
    }
  }
}

// -------------------------------
// Azure Front Door Premium Profile + Endpoint
// -------------------------------
resource afdProfile 'Microsoft.Cdn/profiles@2024-02-01' = {
  name: afdProfileName
  location: 'Global'
  tags: tags
  sku: {
    name: 'Premium_AzureFrontDoor'
  }
  properties: {}
}

// FIX: In Bicep, child resources must use `parent:`. Slash-delimited names are ARM JSON notation and cause compilation errors in Bicep.
resource afdEndpoint 'Microsoft.Cdn/profiles/afdEndpoints@2024-02-01' = {
  parent: afdProfile
  name: afdEndpointName
  location: 'Global'
  properties: {
    enabledState: 'Enabled'
  }
}

// -------------------------------
// Origin Group + Origins (Private Link)
// -------------------------------
// FIX: In Bicep, child resources must use `parent:`. Slash-delimited names are ARM JSON notation and cause compilation errors in Bicep.
resource originGroup 'Microsoft.Cdn/profiles/originGroups@2024-02-01' = {
  parent: afdProfile
  name: originGroupName
  properties: {
    // Health probe MUST hit a simple, unauthenticated endpoint.
    // Using '/' often triggers redirects/auth/DB calls and creates false Unhealthy.
    healthProbeSettings: {
      probePath: '/health'
      probeRequestType: 'GET'
      probeProtocol: 'Https'
      probeIntervalInSeconds: 30
    }
    loadBalancingSettings: {
      sampleSize: 4
      successfulSamplesRequired: 3
      additionalLatencyInMilliseconds: 0
    }
  }
}

// FIX: In Bicep, child resources must use `parent:`. Slash-delimited names are ARM JSON notation and cause compilation errors in Bicep.
resource primaryOrigin 'Microsoft.Cdn/profiles/originGroups/origins@2024-02-01' = {
  parent: originGroup
  name: 'origin-neu'
  properties: {
    hostName: originHostHeader
    originHostHeader: originHostHeader
    enabledState: 'Enabled'
    priority: 1
    weight: 1000

    // Portfolio-friendly: avoid TLS name mismatch while still forcing HTTPS.
    // In production: set enforceCertificateNameCheck=true + use a real domain/cert.
    enforceCertificateNameCheck: false

    sharedPrivateLinkResource: {
      privateLink: {
        id: primaryAgwResourceId
      }
      privateLinkLocation: 'northeurope'
      groupId: 'appGatewayFrontendIp'
      requestMessage: 'Azure Front Door → App Gateway (primary)'
    }
  }
}

// FIX: In Bicep, child resources must use `parent:`. Slash-delimited names are ARM JSON notation and cause compilation errors in Bicep.
resource secondaryOrigin 'Microsoft.Cdn/profiles/originGroups/origins@2024-02-01' = {
  parent: originGroup
  name: 'origin-weu'
  properties: {
    hostName: originHostHeader
    originHostHeader: originHostHeader
    enabledState: 'Enabled'
    priority: 2
    weight: 1000
    enforceCertificateNameCheck: false
    sharedPrivateLinkResource: {
      privateLink: {
        id: secondaryAgwResourceId
      }
      privateLinkLocation: 'westeurope'
      groupId: 'appGatewayFrontendIp'
      requestMessage: 'Azure Front Door → App Gateway (secondary)'
    }
  }
}

// -------------------------------
// Route (HTTPS only)
// -------------------------------
// FIX: In Bicep, child resources must use `parent:`. Slash-delimited names are ARM JSON notation and cause compilation errors in Bicep.
resource afdRoute 'Microsoft.Cdn/profiles/afdEndpoints/routes@2024-02-01' = {
  parent: afdEndpoint
  name: routeName
  // Ensure origins + WAF association exist before route creation.
  dependsOn: [
    primaryOrigin
    secondaryOrigin
    securityPolicy
  ]
  properties: {
    originGroup: {
      id: originGroup.id
    }
    supportedProtocols: [
      'Https'
    ]
    httpsRedirect: 'Enabled'
    forwardingProtocol: 'HttpsOnly'
    patternsToMatch: [
      '/*'
    ]
    linkToDefaultDomain: 'Enabled'
    enabledState: 'Enabled'
  }
}

// -------------------------------
// Security Policy: bind WAF to the endpoint
// -------------------------------
// FIX: In Bicep, child resources must use `parent:`. Slash-delimited names are ARM JSON notation and cause compilation errors in Bicep.
resource securityPolicy 'Microsoft.Cdn/profiles/securityPolicies@2024-02-01' = {
  parent: afdProfile
  name: securityPolicyName
  properties: {
    parameters: {
      type: 'WebApplicationFirewall'
      wafPolicy: {
        id: wafPolicy.id
      }
      associations: [
        {
          domains: [
            {
              id: afdEndpoint.id
            }
          ]
          patternsToMatch: [
            '/*'
          ]
        }
      ]
    }
  }
}

// -------------------------------
// Outputs
// -------------------------------
@description('Resource ID of the Front Door profile.')
output afdProfileId string = afdProfile.id

@description('Front Door endpoint hostname (e.g., <name>.azurefd.net).')
output afdEndpointHostname string = afdEndpoint.properties.hostName

@description('Resource ID of the WAF policy attached to the Front Door endpoint.')
output wafPolicyId string = wafPolicy.id
