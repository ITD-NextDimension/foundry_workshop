#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Preflight checks + per-student naming uniqueness for `azd up`.

.DESCRIPTION
    Run from inside your Track folder (where `azd env get-value AZURE_RESOURCE_GROUP`
    returns a value) BEFORE `azd up`. Idempotent.

    This script solves three real-world conflicts you hit when ~30 students share
    one Azure subscription:

      1. **Soft-deleted Foundry / Cognitive Services accounts**: a previous
         `azd down --purge` may have failed to fully purge; the account name
         is then locked for ~60 days. We sweep & purge any soft-deleted
         CogServices accounts that would collide with the about-to-be-created
         name.

      2. **Global namespace collisions on retries** (Static Web App, ACR,
         Storage): we generate a 4-char random salt the first time we run,
         persist it to `azd env` as `WORKSHOP_NAME_SUFFIX`, and the SWA bicep
         + parameters.json picks it up so the SWA name is unique per attempt.

      3. **Pre-existing resources in the RG**: we print the *expected* resource
         names so the student can spot conflicts before the long bicep
         deployment burns wall-clock time.

    Note: the starter's main.bicep already derives its own resourceToken from
    `uniqueString(subscription().id, resourceGroup().id, location)`. As long as
    each student has a unique RG name (the recommended workshop layout) the
    Foundry account / ACR / storage names are unique without any salt. This
    script's salt only affects *workshop-added* resources (SWA) and is enough
    to make repeated retries in the same RG safe.

.PARAMETER Force
    Re-roll the WORKSHOP_NAME_SUFFIX salt even if one is already set. Use this
    when you have a hard collision you want to break out of.

.EXAMPLE
    cd workshop/track-A
    ..\workshop-scripts\preflight.ps1

.EXAMPLE
    ..\workshop-scripts\preflight.ps1 -Force    # re-roll the salt
#>
[CmdletBinding()]
param(
    [switch]$Force,
    [switch]$SkipPurge
)

$ErrorActionPreference = 'Stop'

function Get-AzdEnv($name) {
    $v = & azd env get-value $name 2>$null
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($v)) { return $null }
    return $v.Trim()
}

# ----- 0. Sanity ---------------------------------------------------------
$sub = Get-AzdEnv AZURE_SUBSCRIPTION_ID
$rg  = Get-AzdEnv AZURE_RESOURCE_GROUP
$loc = Get-AzdEnv AZURE_LOCATION

if (-not $sub -or -not $rg -or -not $loc) {
    Write-Host "❌ AZURE_SUBSCRIPTION_ID / AZURE_RESOURCE_GROUP / AZURE_LOCATION not all set." -ForegroundColor Red
    Write-Host "   Run these first (see lab-1):" -ForegroundColor DarkGray
    Write-Host "     azd env set AZURE_SUBSCRIPTION_ID <subId>" -ForegroundColor DarkGray
    Write-Host "     azd env set AZURE_RESOURCE_GROUP   <yourRg>" -ForegroundColor DarkGray
    Write-Host "     azd env set AZURE_LOCATION         <region>" -ForegroundColor DarkGray
    exit 1
}

Write-Host "Sub : $sub" -ForegroundColor DarkGray
Write-Host "RG  : $rg" -ForegroundColor DarkGray
Write-Host "Loc : $loc" -ForegroundColor DarkGray
Write-Host ""

# ----- 1. Generate or re-use WORKSHOP_NAME_SUFFIX ------------------------
$salt = Get-AzdEnv WORKSHOP_NAME_SUFFIX
if ($Force -or [string]::IsNullOrWhiteSpace($salt)) {
    $alphabet = 'abcdefghijklmnopqrstuvwxyz0123456789'.ToCharArray()
    $salt = -join (1..4 | ForEach-Object { $alphabet | Get-Random })
    azd env set WORKSHOP_NAME_SUFFIX $salt | Out-Null
    Write-Host "✅ Generated WORKSHOP_NAME_SUFFIX = $salt" -ForegroundColor Green
} else {
    Write-Host "ℹ Re-using existing WORKSHOP_NAME_SUFFIX = $salt" -ForegroundColor DarkGray
}

# ----- 2. Compute expected resource names --------------------------------
# Mirrors uniqueString(subscription().id, resourceGroup().id, location) — but
# uniqueString's exact algorithm isn't reproducible in PowerShell. We use a
# 13-char SHA256 hash as a *preview* — actual ARM names may differ slightly.
$hashInput = "${sub}|${rg}|${loc}"
$hash = [System.Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($hashInput))
$hex  = ([System.BitConverter]::ToString($hash) -replace '-','').ToLower()
$token = $hex.Substring(0,13)   # ~ uniqueString-length preview

Write-Host ""
Write-Host "Expected workshop-owned resource names (preview):" -ForegroundColor Cyan
Write-Host "  SWA      : swa-workshop-<token>-$salt   (where <token>≈$token)" -ForegroundColor DarkGray
Write-Host "  Foundry  : ai-account-<starterToken>     (starter-controlled)" -ForegroundColor DarkGray
Write-Host "  ACR      : cr<starterToken>              (starter-controlled)" -ForegroundColor DarkGray
Write-Host ""

# ----- 3. Purge soft-deleted CogServices accounts that match -------------
if (-not $SkipPurge) {
    Write-Host "Scanning for soft-deleted Foundry / CogServices accounts ..." -ForegroundColor Cyan
    $deleted = az cognitiveservices account list-deleted --subscription $sub --query "[?resourceGroup=='$rg']" -o json 2>$null | ConvertFrom-Json
    if ($null -ne $deleted -and $deleted.Count -gt 0) {
        foreach ($acc in $deleted) {
            Write-Host "  Purging soft-deleted: $($acc.name) ($($acc.location))" -ForegroundColor Yellow
            az cognitiveservices account purge --location $acc.location --resource-group $rg --name $acc.name --subscription $sub 2>&1 | Out-Null
            if ($LASTEXITCODE -eq 0) {
                Write-Host "  ✅ Purged $($acc.name)" -ForegroundColor Green
            } else {
                Write-Host "  ⚠ Failed to purge $($acc.name) — name may stay reserved for ~60d" -ForegroundColor Yellow
            }
        }
    } else {
        Write-Host "  (none found)" -ForegroundColor DarkGray
    }
}

# ----- 4. Warn if the target RG looks foreign ----------------------------
$rgInfo = az group show --name $rg --subscription $sub -o json 2>$null | ConvertFrom-Json
if ($null -eq $rgInfo) {
    Write-Host "⚠ Resource group '$rg' not found in subscription $sub." -ForegroundColor Yellow
    Write-Host "  `azd up` will try to create it — make sure your SP has rights to create RGs at sub scope" -ForegroundColor DarkGray
    Write-Host "  (workshop SPs are scoped to an existing RG and CANNOT create new RGs)." -ForegroundColor DarkGray
} else {
    Write-Host "✅ RG '$rg' exists ($($rgInfo.location), provisioningState=$($rgInfo.properties.provisioningState))" -ForegroundColor Green
    if ($rgInfo.location -ne $loc) {
        Write-Host "⚠ RG location ($($rgInfo.location)) differs from AZURE_LOCATION ($loc). Bicep deployment may fail." -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "Preflight done. Next:" -ForegroundColor Cyan
Write-Host "  ..\workshop-scripts\install-swa-patch.ps1   # one-time, idempotent" -ForegroundColor DarkGray
Write-Host "  azd up --no-prompt" -ForegroundColor DarkGray
