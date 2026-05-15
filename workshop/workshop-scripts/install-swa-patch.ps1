#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Patches the azd-ai-starter-basic main.bicep to include the workshop SWA module.

.DESCRIPTION
    Run AFTER `azd init -t Azure-Samples/azd-ai-starter-basic -e dev --no-prompt`
    and BEFORE `azd up`. Idempotent — second run is a no-op.

.EXAMPLE
    cd workshop/track-A
    ../workshop-scripts/install-swa-patch.ps1
#>
[CmdletBinding()]
param(
    [string]$MainBicep = ".\infra\main.bicep"
)

if (-not (Test-Path $MainBicep)) {
    Write-Host "❌ $MainBicep not found. Run from a folder where 'azd init -t azd-ai-starter-basic' has been run." -ForegroundColor Red
    exit 1
}

$content = Get-Content $MainBicep -Raw

if ($content -match "module workshopSwa") {
    Write-Host "✅ SWA module already patched into $MainBicep — nothing to do." -ForegroundColor Green
    exit 0
}

$patch = @"

// =========================================================================
// Workshop add-on: Static Web App for the observability dashboard (Lab 4).
// Patched in by workshop-scripts/install-swa-patch.ps1.
// =========================================================================
module workshopSwa './../../infra/swa.bicep' = {
  name: 'workshop-swa'
  params: {
    resourceToken: resourceToken
    applicationInsightsName: applicationInsights.outputs.name
    tags: tags
  }
}

output SWA_URL string = workshopSwa.outputs.swaUrl
"@

Add-Content -Path $MainBicep -Value $patch -Encoding UTF8
Write-Host "✅ Patched $MainBicep with workshop SWA module." -ForegroundColor Green
Write-Host "   Next:  azd up --no-prompt" -ForegroundColor DarkGray
