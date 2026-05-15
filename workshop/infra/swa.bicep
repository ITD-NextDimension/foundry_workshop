// ============================================================================
// Workshop add-on infra:
//   - Static Web App (free tier) for the observability dashboard
//   - Role assignments so the SWA's system-assigned MI can read App Insights
//
// This is loaded as a sub-module from `azd-ai-starter-basic`'s main.bicep
// (or you can include it standalone if you prefer to manage Foundry separately).
//
// Inputs:
//   - resourceGroupName / location are inherited
//   - applicationInsightsName / logAnalyticsWorkspaceName come from the starter
// Outputs:
//   - swaUrl                    -> set as env AZURE_AI_*_URL via post-provision hook
//   - applicationInsightsAppId  -> wired into SWA Functions app settings
// ============================================================================

@description('Suffix used for naming uniqueness.')
param resourceToken string

@description('Location for the SWA. SWA is regional; pick something close to App Insights.')
param swaLocation string = 'eastasia'

@description('App Insights resource name (created by the starter).')
param applicationInsightsName string

@description('Tag set applied to all resources.')
param tags object = {}

// ---------- existing references ----------
resource appInsights 'Microsoft.Insights/components@2020-02-02' existing = {
  name: applicationInsightsName
}

// ---------- SWA ----------
resource swa 'Microsoft.Web/staticSites@2023-12-01' = {
  name: 'swa-workshop-${resourceToken}'
  location: swaLocation
  tags: union(tags, { 'azd-service-name': 'observability' })
  sku: {
    name: 'Free'
    tier: 'Free'
  }
  properties: {
    // Code is deployed by `azd deploy observability`; we just provision the SWA.
    stagingEnvironmentPolicy: 'Enabled'
  }
  identity: {
    type: 'SystemAssigned'
  }
}

// App settings for the API
resource swaAppSettings 'Microsoft.Web/staticSites/config@2023-12-01' = {
  parent: swa
  name: 'appsettings'
  properties: {
    APPINSIGHTS_APPLICATION_ID: appInsights.properties.AppId
    WORKSHOP_DEFAULT_AGENT: 'billing-agent'
  }
}

// ---------- Role assignment: SWA MI -> Monitoring Reader on App Insights ----------
// 'Monitoring Reader' built-in role
var monitoringReaderRoleId = '43d0d8ad-25c7-4714-9337-8ba259a9fe05'

resource swaMonitoringReader 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(appInsights.id, swa.id, monitoringReaderRoleId)
  scope: appInsights
  properties: {
    principalId: swa.identity.principalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', monitoringReaderRoleId)
    principalType: 'ServicePrincipal'
  }
}

// ---------- outputs ----------
output swaUrl string = 'https://${swa.properties.defaultHostname}'
output swaName string = swa.name
output applicationInsightsAppId string = appInsights.properties.AppId
