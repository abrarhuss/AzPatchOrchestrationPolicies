<#
.SYNOPSIS
    Deploys the VM patch orchestration policy definitions and initiative to a subscription.

.DESCRIPTION
    Creates (or updates) the four custom policy definitions first, then the policy set
    definition (initiative). The initiative JSON references its member policies via
    ARM-style [concat(subscription().id, ...)] expressions; this script resolves those
    to literal subscription-scoped IDs before creating the set definition.

.PARAMETER SubscriptionId
    Target subscription. Defaults to the current Az context subscription.

.EXAMPLE
    ./Deploy-Policies.ps1
    ./Deploy-Policies.ps1 -SubscriptionId "00000000-0000-0000-0000-000000000000"
#>
[CmdletBinding()]
param(
    [string]$SubscriptionId
)

$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot

# --- Context -----------------------------------------------------------------
if ($SubscriptionId) {
    Set-AzContext -Subscription $SubscriptionId | Out-Null
}
$ctx = Get-AzContext
if (-not $ctx) { throw "Not signed in. Run Connect-AzAccount first." }
$subId = $ctx.Subscription.Id
$subScope = "/subscriptions/$subId"
Write-Host "Deploying to subscription: $subId" -ForegroundColor Cyan

# --- Helper: load the wrapped policy JSON ------------------------------------
function Get-PolicyJson([string]$file) {
    Get-Content -Raw -Path (Join-Path $root $file) | ConvertFrom-Json
}

# --- 1. Policy definitions ---------------------------------------------------
$definitions = @(
    'Deny-WindowsVMPatchOrchestration.json',
    'Deny-LinuxVMPatchOrchestration.json',
    'Modify-WindowsVMPatchOrchestration.json',
    'Modify-LinuxVMPatchOrchestration.json'
)

foreach ($file in $definitions) {
    $def = Get-PolicyJson $file
    $p = $def.properties

    Write-Host "Creating policy definition: $($def.name)" -ForegroundColor Green
    $params = @{
        Name        = $def.name
        DisplayName = $p.displayName
        Description = $p.description
        Policy      = ($p.policyRule | ConvertTo-Json -Depth 50)
        Parameter   = ($p.parameters | ConvertTo-Json -Depth 50)
        Metadata    = ($p.metadata   | ConvertTo-Json -Depth 50)
        Mode        = $p.mode
    }
    New-AzPolicyDefinition @params | Out-Null
}

# --- 2. Initiative (policy set definition) -----------------------------------
$initRaw = Get-Content -Raw -Path (Join-Path $root 'Initiative-VMPatchOrchestration.json')
$init    = $initRaw | ConvertFrom-Json
$ip      = $init.properties

# Resolve [concat(subscription().id, '...')] -> /subscriptions/<id>/...
$defsJson = $ip.policyDefinitions | ConvertTo-Json -Depth 50
$defsJson = $defsJson.Replace("[concat(subscription().id, '", $subScope).Replace("')]", "")

Write-Host "Creating policy set definition: $($init.name)" -ForegroundColor Green
$setParams = @{
    Name             = $init.name
    DisplayName      = $ip.displayName
    Description      = $ip.description
    PolicyDefinition = $defsJson
    Parameter        = ($ip.parameters | ConvertTo-Json -Depth 50)
    Metadata         = ($ip.metadata   | ConvertTo-Json -Depth 50)
}
New-AzPolicySetDefinition @setParams | Out-Null

Write-Host "Done. 4 policy definitions + 1 initiative deployed." -ForegroundColor Cyan
