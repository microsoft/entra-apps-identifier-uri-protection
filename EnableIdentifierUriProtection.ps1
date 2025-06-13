#Requires -Version 7.2.0
<#
.SYNOPSIS
    Powershell script to set NonDefaultUriAddition or uriAdditionWithoutUniqueTenantIdentifier restriction on the Tenant Default Application Management Policy.
.DESCRIPTION
    This PowerShell script is intended to update tenant application management policy in an Entra ID tenant and set
    a new restriction called NonDefaultUriAddition for the IdentifierUris property on applications and service principal objects.
    The script will enable the tenant policy if it is disabled.
    Please see SetTenantPolicyRestriction.md for more details.
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
    The restriction to enable: 'nonDefaultUriAddition' or 'uriAdditionWithoutUniqueTenantIdentifier'.
    Default: uriAdditionWithoutUniqueTenantIdentifier
.PARAMETER RestrictForAppsCreatedAfterDateTime
    Optional. Date used as RestrictForAppsCreatedAfterDateTime to apply the new identifierUris restriction only for applications and setvice principals
    created after a certain date. If not provided, the restriction will apply to all applications and service principals.
    Default: null
.EXAMPLE
    EnableIdentifierUriProtection.ps1
    To run the script and log output without updating application management policies 
.EXAMPLE
    EnableIdentifierUriProtection.ps1 -WhatIf $true
    To run the script and log the application management policies changes
.NOTES
    Author: Yogesh Randhawa
    Date:   08 Nov 2024  
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
        Default: false"
    )]
    [bool]$WhatIf = $false,
    [Parameter(
        HelpMessage="The restriction to enable: 'nonDefaultUriAddition' or 'uriAdditionWithoutUniqueTenantIdentifier'. Default: uriAdditionWithoutUniqueTenantIdentifier"
    )]
    [ValidateSet("uriAdditionWithoutUniqueTenantIdentifier", "nonDefaultUriAddition")]
    [string]$Restriction = "uriAdditionWithoutUniqueTenantIdentifier",
    [Parameter(
        HelpMessage="Optional. Date used as RestrictForAppsCreatedAfterDateTime to apply the new restriction only for applications and setvice principals created after
        a certain date. If not provided, the restriction will apply to all applications and service principals.
        Default: null"
    )]
    [string]$RestrictForAppsCreatedAfterDateTime = $null
)

Write-Host "Script starting. Confirming environment setup..."

Import-Module $PSScriptRoot\Modules\AppManagementPolicies.psm1 -Force
Set-DebugAppManagementPolicies($DebugPreference)

Import-Module $PSScriptRoot\Modules\AppManagementPolicyRestrictions.psm1 -Force
Set-DebugAppManagementPolicyRestrictions($DebugPreference)

Write-Debug "Checking if Microsoft.Graph module is installed..."
Assert-ModuleExists -ModuleName "Microsoft.Graph" -InstallLink "https://learn.microsoft.com/en-us/powershell/microsoftgraph/installation?view=graph-powershell-1.0"

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

try {
    # Get Tenant Application Management Policy
    $Tenant_Policy = Get-TenantApplicationManagementPolicy
    Write-Host "Found 'Tenant' policy"    
} catch {
    Write-Error "Failed to get Tenant Application Management Policy. Please check your logs for errors and try again."
    Write-Error "Error: $($_.Exception.Message)"
    Invoke-Exit $Logout
    return
}

try {
    # Update Tenant Application Management Policy With new IdentifierUris restriction
    $newPolicy = Set-ApplicationManagementPolicyRestriction_IdentifierUris `
        -PolicyType "Tenant" `
        -Policy $Tenant_Policy `
        -RestrictionTypeName $Restriction `
        -RestrictForAppsCreatedAfterDateTime $RestrictForAppsCreatedAfterDateTime `
        -WhatIf $WhatIf

    if (-not $newPolicy.isEnabled) {
        Write-Warning "Enabling the tenant policy. This will apply the policy restriction '$Restriction' to all applications and service principals."
        $newPolicy.isEnabled = $true
    }

    # Access the restriction object dynamically
    if ($Restriction -eq "uriAdditionWithoutUniqueTenantIdentifier") {
        $RestrictionObj = $newPolicy.applicationRestrictions.identifierUris.uriAdditionWithoutUniqueTenantIdentifier
    } elseif ($Restriction -eq "nonDefaultUriAddition") {
        $RestrictionObj = $newPolicy.applicationRestrictions.identifierUris.nonDefaultUriAddition
    } else {
        Write-Error "Invalid restriction specified. Please use 'nonDefaultUriAddition' or 'uriAdditionWithoutUniqueTenantIdentifier'."
        Invoke-Exit $Logout
        return
    }

    # Print error if $RestrictionObj is null
    if (-not $RestrictionObj) {
        Write-Error "The restriction object for '$Restriction' is null. Please verify the policy and restriction type."
        Invoke-Exit $Logout
        return
    }

    if (-not $RestrictionObj.excludeAppsReceivingV2Tokens) {
        Write-Message -Color "Yellow" -Message "Enabling excludeAppsReceivingV2Tokens on the $Restriction restriction."
        $RestrictionObj.excludeAppsReceivingV2Tokens = $true
    }

    if (-not $RestrictionObj.excludeSaml) {
        Write-Message -Color "Yellow" -Message "Enabling excludeSaml on the $Restriction restriction."
        $RestrictionObj.excludeSaml = $true
    }

    # Update the policy
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

Write-Message -Message "Identifier URIs protection '$Restriction' successfully enabled."

Invoke-Exit $Logout
# SIG # Begin signature block
# MIIFxQYJKoZIhvcNAQcCoIIFtjCCBbICAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCBchaQLqBwxkmRL
# fBsb7ynU5e94F180Cq6mJ2y9ot15QaCCAzowggM2MIICHqADAgECAhBuQViVGZw2
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
# gjcCARUwLwYJKoZIhvcNAQkEMSIEIOcmQzVWLgaWidZBAAUnpcDpe/CDOLbipv4W
# 1Au62kOVMA0GCSqGSIb3DQEBAQUABIIBAB4A9A+7RkhzVhr9X86A1lpd81yorZOb
# ztMr7DvBADAZRDrVaqq5i6Or/4de9wQPcsCREyvTfs/Fmr18YYKFxZIxsFO0qDca
# JQUR/zCY7i3pbEVJG4ks0cQA64DR+holbkBcex+oDRPitDW+Fe6xN00On++/FHFi
# VFq/KU2Z81WsOzuSvhKvE5+sFSdmMBwAmlVfOO5/PWZFYWfrEM0QVN735bXYtNYf
# P+JpHOstTha5qrC/+oISOuUaSWF4UuSNofuUu1n9101rb4LwaNJnSZxoabJUa/bE
# /Ip6wCRELOqrKElkAdyxs+rcLufmQ+XlxNMtks+s9t5gOaZq/c1kBU0=
# SIG # End signature block
