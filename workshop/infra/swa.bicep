// ============================================================================
// Workshop add-on infra:
//   - Static Web App (Free tier) for the observability dashboard
//
// This is loaded as a sub-module from `azd-ai-starter-basic`'s main.bicep
// by workshop-scripts/install-swa-patch.ps1.
//
// Naming-conflict notes (shared subscription):
//   - SWA names live in the global `*.azurestaticapps.net` namespace.
//   - `resourceToken` already includes RG, so different students get
//     different tokens automatically.
//   - `nameSuffix` (optional) is appended for re-runs in the *same* RG
//     after a botched teardown (e.g. soft-deleted account collisions).
//     `workshop-scripts/preflight.ps1` generates and persists this.
//
// Free-tier limits (do NOT add `identity:` here — SystemAssigned MI is
// only allowed on Standard tier and will fail with `SkuCode 'Free' is
// invalid.` if combined with Free).
// ============================================================================

@description('Suffix used for naming uniqueness (derived from RG by the caller).')
param resourceToken string

@description('Optional per-run salt to avoid global-namespace collisions on retries.')
param nameSuffix string = ''

@description('Location for the SWA. SWA is regional; pick a region that allows Free SKU. Valid: centralus, eastus2, westus2, westeurope, eastasia.')
@allowed([
  'centralus'
  'eastus2'
  'westus2'
  'westeurope'
  'eastasia'
])
param swaLocation string = 'westus2'

@description('App Insights resource name (created by the starter).')
param applicationInsightsName string

@description('Default hosted agent name surfaced to the SWA dashboard.')
param defaultAgentName string = 'agent-framework-agent-basic-responses'

@description('Tag set applied to all resources.')
param tags object = {}

// ---------- existing references ----------
resource appInsights 'Microsoft.Insights/components@2020-02-02' existing = {
  name: applicationInsightsName
}

// ---------- SWA ----------
var swaName = empty(nameSuffix) ? 'swa-workshop-${resourceToken}' : 'swa-workshop-${resourceToken}-${nameSuffix}'

resource swa 'Microsoft.Web/staticSites@2023-12-01' = {
  name: swaName
  location: swaLocation
  tags: union(tags, { 'azd-service-name': 'observability' })
  sku: {
    name: 'Free'
    tier: 'Free'
  }
  properties: {
    stagingEnvironmentPolicy: 'Enabled'
  }
}

// App settings — read by the dashboard / Functions for context.
// (Free tier does not support MI, so the dashboard reads App Insights
// via the AAD token of whoever opens it, not via a SWA-bound identity.)
resource swaAppSettings 'Microsoft.Web/staticSites/config@2023-12-01' = {
  parent: swa
  name: 'appsettings'
  properties: {
    APPINSIGHTS_APPLICATION_ID: appInsights.properties.AppId
    WORKSHOP_DEFAULT_AGENT: defaultAgentName
  }
}

// ---------- outputs ----------
output swaUrl string = 'https://${swa.properties.defaultHostname}'
output swaName string = swa.name
output applicationInsightsAppId string = appInsights.properties.AppId
