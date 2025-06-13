#Requires -Version 7.2.0
<#
.SYNOPSIS
    Powershell script to disable the NonDefaultUriAddition restriction on the Tenant Default Application Management Policy.
.DESCRIPTION
    This PowerShell script is intended to disable the ApplicationRestrictions.IdentifierUris.NonDefaultUriAddition restricton on 
    the tenant application management policy in an Entra ID tenant. WARNING: disabling this restriction may expose your tenant to
    security vulnerabilities. Please see SetTenantPolicyRestriction.md for more details.
.PARAMETER Environment
    Environment to connect to as listed in
    Get-MgEnvironment (https://learn.microsoft.com/en-us/powershell/module/microsoft.graph.authentication/get-mgenvironment?view=graph-powershell-1.0).
    If non specified, will use the Global (public) environment.
    Default: Global
.PARAMETER TenantId
    TenantId to connect to. If non specified, will present a common login page for all tenants.
    Default: common
.PARAMETER Login
    If the script should attempt to login to MS Graph first. You may also login separately using 
    Connect-MgGraph (https://learn.microsoft.com/en-us/powershell/module/microsoft.graph.authentication/connect-mggraph?view=graph-powershell-1.0).
    Default: True
.PARAMETER Logout
    If the script should logout from MS Graph at the end. You may also logout separately using 
    Disconnect-MgGraph (https://learn.microsoft.com/en-us/powershell/module/microsoft.graph.authentication/disconnect-mggraph?view=graph-powershell-1.0).
    Default: True
.PARAMETER WhatIf
    -WhatIf=true will run the script in a what-if mode and only log the updated policies `
    without actually updating them in Entra ID. Run with -WhatIf=false to update the policies.
    Default: False
.PARAMETER Restriction
    The restriction to disable: 'nonDefaultUriAddition' or 'uriAdditionWithoutUniqueTenantIdentifier'. Default: uriAdditionWithoutUniqueTenantIdentifier
    Default: uriAdditionWithoutUniqueTenantIdentifier
.EXAMPLE
    DisableIdentifierUriProtection.ps1
    To run the script and log output without updating application management policies
.EXAMPLE
    DisableIdentifierUriProtection.ps1 -WhatIf $true
    To run the script and log the application management policies to disable the NonDefaultUriAddition restriction.
.NOTES
    Author: Zachary Allison
    Date:   04 Dec 2024  
#>
[CmdletBinding()]
param(
    [Parameter(
        HelpMessage="Environment to connect to as listed in
        [Get-MgEnvironment](https://learn.microsoft.com/en-us/powershell/module/microsoft.graph.authentication/get-mgenvironment?view=graph-powershell-1.0).
        If non specified, will use the Global (public) environment.
        Default: Global"
    )]
    [string]$Environment = "Global",
    [Parameter(
        HelpMessage="TenantId to connect to. If non specified, will present a common login page for all tenants.
        Default: common"
    )]
    [string]$TenantId = "common",
    [Parameter(
        HelpMessage="If the script should attempt to login to MS Graph first. You may also login separately using 
        [Connect-MgGraph](https://learn.microsoft.com/en-us/powershell/module/microsoft.graph.authentication/connect-mggraph?view=graph-powershell-1.0).
        Default: True"
    )]
    [bool]$Login = $true,
    [Parameter(
        HelpMessage="If the script should logout from MS Graph at the end. You may also logout separately using 
        [Disconnect-MgGraph](https://learn.microsoft.com/en-us/powershell/module/microsoft.graph.authentication/disconnect-mggraph?view=graph-powershell-1.0).
        Default: True"
    )]
    [bool]$Logout = $true,
    [Parameter(
        HelpMessage="-WhatIf=true will run the script in a what-if mode and only log the updated policies
        without actually updating them in Entra ID. Run with -WhatIf=false to update the policies.
        Default: False"
    )]
    [bool]$WhatIf = $false,
    [Parameter(
        HelpMessage="The restriction to disable: 'nonDefaultUriAddition' or 'uriAdditionWithoutUniqueTenantIdentifier'. Default: uriAdditionWithoutUniqueTenantIdentifier"
    )]
    [ValidateSet("uriAdditionWithoutUniqueTenantIdentifier", "nonDefaultUriAddition")]
    [string]$Restriction = "uriAdditionWithoutUniqueTenantIdentifier"
)

Write-Host "Script starting. Confirming environment setup..."

Import-Module $PSScriptRoot\Modules\AppManagementPolicies.psm1 -Force
Set-DebugAppManagementPolicies($DebugPreference)

Import-Module $PSScriptRoot\Modules\AppManagementPolicyRestrictions.psm1 -Force
Set-DebugAppManagementPolicyRestrictions($DebugPreference)

Write-Debug "Checking if Microsoft.Graph module is installed..."
Assert-ModuleExists -ModuleName "Microsoft.Graph" -InstallLink "https://learn.microsoft.com/en-us/powershell/microsoftgraph/installation?view=graph-powershell-1.0"

Write-Message -Color "Red" -Message "WARNING: Disabling the IdentifierUri restriction will reduce the security of your tenant."

if ($true -eq $WhatIf) {
    Write-Warning "What-If mode in ON"
    Write-Warning "The script was run without -WhatIf parameter or with '-WhatIf `$true`'."
    Write-Warning "The script will not update the tenant application management policy in Entra ID but will log the updated policy."
    Write-Warning "To update the policy in Entra ID, re-run the script with What-If mode off using param '-WhatIf `$false`'."
}

# Set the Environment for the connections.
Set-ExecutionEnvironment -Environment $Environment

if ($true -eq $Login) {
    # Login to MS Graph interactively
    # Use Global Admin creds at prompt
    Start-Login -TenantId $TenantId
}

# Get Tenant Application Management Policy
try {
    $Tenant_Policy = Get-TenantApplicationManagementPolicy
    Write-Debug "Found 'Tenant' policy"
} catch {
    Write-Error "Failed to get Tenant Application Management Policy. Please check your logs for errors and try again."
    Write-Error "Error: $($_.Exception.Message)"
    
    Invoke-Exit $Logout
    return
}

# Update Tenant Application Management Policy With new restriction in a disabled state.
$newPolicy = Set-ApplicationManagementPolicyRestriction_IdentifierUris `
    -PolicyType "Tenant" `
    -Policy $Tenant_Policy `
    -RestrictionTypeName $Restriction `
    -RestrictForAppsCreatedAfterDateTime $null `
    -WhatIf $WhatIf `
    -State "disabled"

# Update the policy
try {
    Update-ApplicationManagementPolicy "Tenant" $newPolicy $WhatIf
} catch {
    Write-Error "Failed to update Tenant Application Management Policy. Please check your logs for errors and try again."
    Write-Error "Error: $($_.Exception.Message)"
    Invoke-Exit $Logout
    return
}

if ($true -eq $WhatIf) {
    Write-Warning "What-If mode is ON"
    Write-Warning "The script was run with no -WhatIf parameter or with '-WhatIf `$true`'."
    Write-Warning "Tenant application management policy was not updated in Entra ID."

    Invoke-Exit $Logout
    return
}

Write-Message -Message "Identifier URI protection '$Restriction' successfully disabled. To re-enable, run ./EnableIdentifierUriProtection.ps1 with the appropriate restriction."

Invoke-Exit $Logout
# SIG # Begin signature block
# MIIFxQYJKoZIhvcNAQcCoIIFtjCCBbICAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCBy5QZVBTiYnYgG
# TklS6/b8Rg3Pzh0le/UVJMbsL9fnrKCCAzowggM2MIICHqADAgECAhBuQViVGZw2
# u08Xv6xOUdioMA0GCSqGSIb3DQEBCwUAMCQxIjAgBgNVBAMMGVRlc3RBenVyZUVu
# Z0J1aWxkQ29kZVNpZ24wHhcNMTkxMjE2MjM1NDA5WhcNMzAwNzE3MDAwNDA5WjAk
# MSIwIAYDVQQDDBlUZXN0QXp1cmVFbmdCdWlsZENvZGVTaWduMIIBIjANBgkqhkiG
# 9w0BAQEFAAOCAQ8AMIIBCgKCAQEAt3OiYZyc8h9WttCZ6z9jOOlhCLOWcw89wdEY
# vJDfrChveFm01zK042ou5NOYqKEHDdN29qcJIDrqEtanKvM9JZjaivFGjEA63HGu
# ALbXwvmN/Blt2lFiM0QiSQ8Rycp4rapy60Fwo9acVEgsKmIl7WZ9bdFGaLhdap2o
# yvpEpbThHNybMnWIQ/93gQjwGr0oEX6haIa3I4w5Cnoyj6MOT7TeaL6Wm9t9ZetI
# fegpiEjB/NzSm8xdhmaR18Qld9vRRzh0ZSm6Vh6DEu5zw7GTs19mdnbhmSsojyxj
# WKZP+Z4L9QvNjxlQsodKro2G/mcK/cj9oeaQaDfBM+5n8/pEBQIDAQABo2QwYjAO
# BgNVHQ8BAf8EBAMCB4AwEwYDVR0lBAwwCgYIKwYBBQUHAwMwHAYDVR0RBBUwE4IR
# d3d3Lm1pY3Jvc29mdC5jb20wHQYDVR0OBBYEFBp3bKlqiwVI3dY3j0X8HV/Ekuu/
# MA0GCSqGSIb3DQEBCwUAA4IBAQCZLCnXnyJFwPt/+r4/kYxqqgraLut+aIlbFmpn
# uQ+WlbHhXuaTApaqt+EhfFRoWaM5kv8Npy2N0VDVwg9cXxAI+Y9zbIgCQXAwBWAF
# CY506zjalEVFW6BKtfI8B/Hn0M+7feZXqqPxvfT4ZfYotgy2jgDo7sDt5Phhq82+
# gC5R2+VMpnbjUGuor/fKQrIntV80qEuCcmuT/x63Ra7w33KnrBlwI78sG7DfG4UB
# yIcOccU0ehbpyAvOmR3SdsBxquSYc+aSl7HVXGhN9RPYNN9AAEZfRO5CnFf8942v
# L6JT+uVv4o7leTokSiRI/8qoEoU+F87igWkn3VBy8ZvH5o6lMYIB4TCCAd0CAQEw
# ODAkMSIwIAYDVQQDDBlUZXN0QXp1cmVFbmdCdWlsZENvZGVTaWduAhBuQViVGZw2
# u08Xv6xOUdioMA0GCWCGSAFlAwQCAQUAoHwwEAYKKwYBBAGCNwIBDDECMAAwGQYJ
# KoZIhvcNAQkDMQwGCisGAQQBgjcCAQQwHAYKKwYBBAGCNwIBCzEOMAwGCisGAQQB
# gjcCARUwLwYJKoZIhvcNAQkEMSIEIDCQNpXFq2+NQ88wl98Iuja1rPUkZa62MiDJ
# rnT4SizGMA0GCSqGSIb3DQEBAQUABIIBAHqua9hg4vF+NyEmdsBxhhRaVoumAbsC
# QIE+FHybOREI7b7gDfwoA6qN/ykseD+B4s6g1a6yn+vZHJ4zpm8e7IhgqCoLMf0I
# b6AQ8vP6924w49Iz3Y73yhuIaGA3aUsvpCHof5JJHwxv9DVgZiXkMsR6L/WYRj2A
# syiLoFTBVzzEgSZ13Yh00cxIGh6JX75RXRWJPcOZZ/dP1ZblFq7vwGEaVIWVUCRt
# +TK8LFbuaDE4WqG/ttgAWJr1LAlV1Oj2kZsftX1x2MBjLqjwBEHGJE/HNIbffNqi
# uGl+jLbEh8+IN4eUFL2clevYpGYOQkQ/VXI6ZrXF+YdAkTVIrYMH2YM=
# SIG # End signature block
