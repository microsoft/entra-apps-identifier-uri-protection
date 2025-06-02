#Requires -Version 7.2.0

<#
.SYNOPSIS
    Powershell script to un-exempt an Application from the IdentifierUris NonDefaultUriAddition restriction.
.DESCRIPTION
    A recent Entra security update enables Tenant Admins to restrict the addition of custom Identifier URIs to applications.
    This script simplifies the process of revoking an exemption to an Application from the nonDefaultUriAddition AppManagementPolicy enforcement.

    Applications are exempted from the NonDefaultUriAddition restriction when they have an assigned custom AppManagementPolicy with the nonDefaultUriAddition property state set to 'disabled'.

    This script performs the following modifications to the tenant:
    1. Sets the attached AppManagementPolicy's nonDefaultUriAddition property state to 'enabled'
    2. Removes the existing AppManagementPolicy from the Application if it is the default "Identifier URI addition exemption" policy.

    Prerequisites for executing the script:
    - PowerShell 7.2.0 or later
    - Microsoft.Graph module
    - Minimum required roles for Admin performing this script:
        - Cloud Application Administrator
.PARAMETER AppId
    The Application AppId to revoke the IdentifierUris NonDefaultUriAddition restriction exemption. Required.
.PARAMETER Environment
    Environment to connect to as listed in
    Get-MgEnvironment (https://learn.microsoft.com/en-us/powershell/module/microsoft.graph.authentication/get-mgenvironment?view=graph-powershell-1.0).
    Default: Global
.PARAMETER TenantId
    TenantId to connect to. This is used if the user has multiple tenants and needs to specify which tenant to run the script against.
    Default: common
.PARAMETER Login
    If the script should attempt to login to MS Graph first. You may also login separately using 
    Connect-MgGraph (https://learn.microsoft.com/en-us/powershell/module/microsoft.graph.authentication/connect-mggraph?view=graph-powershell-1.0).
    $false should be used if the Connect-MgGraph command has already been run in the current Powershell session.
    This allows the user to customize their MS Graph connection through Connect-MgGraph without being constrained by the script's narrow implementation.
    Default: True
.PARAMETER Logout
    If the script should logout from MS Graph at the end. You may also logout separately using 
    Disconnect-MgGraph (https://learn.microsoft.com/en-us/powershell/module/microsoft.graph.authentication/disconnect-mggraph?view=graph-powershell-1.0).
    $false is recommended if further scripting or actions by the Tenant Admin are required after the script completes.
    Default: True
.PARAMETER WhatIf
    -WhatIf=true will run the script in a what-if mode and only log the updated policies `
    without actually updating them in Entra ID. Run with -WhatIf=false to update the policies.
    Default: False
.EXAMPLE
    RemoveAppExemption.ps1 -AppId "12345678-1234-1234-1234-123456789012" -WhatIf $true
    To run the script and review the log output without updating any objects in the tenant. Used to verify the script actions before committing the changes to the tenant.
.EXAMPLE
    RemoveAppExemption.ps1 -AppId "12345678-1234-1234-1234-123456789012" -WhatIf $false
    To run the script and remove the current AppManagementPolicy assigned to the App.
.EXAMPLE
    RemoveAppExemption.ps1 -AppId "12345678-1234-1234-1234-123456789012" -TenantId "961581b0-b5e9-4872-a9cf-83a2a9f975ab"
    To login to the specified tenant. This is used if the user has multiple tenants and needs to specify which tenant to run the script against. Cannot be used with -Login $false as this flag overrides the -TenantId functionality.
.EXAMPLE
    RemoveAppExemption.ps1 -AppId "12345678-1234-1234-1234-123456789012" -Debug
    To run the script and view the detailed debug output. Used for troubleshooting any errors.
.EXAMPLE
    RemoveAppExemption.ps1 -AppId "12345678-1234-1234-1234-123456789012" -WhatIf $true -Logout $false

    RemoveAppExemption.ps1 -AppId "12345678-1234-1234-1234-123456789012" -WhatIf $false -Login $false

    To run the script in both -WhatIf modes without repeating the login flow.
.NOTES
    Author: Zachary Allison
    Date:   06 Dec 2024
#>
[CmdletBinding()]
param(
    [Parameter(
        HelpMessage="The Application AppId to remove the exemption from. Required.",
        Mandatory=$true
    )]
    [string]$AppId,
    [Parameter(
        HelpMessage="Environment to connect to as listed in
        [Get-MgEnvironment](https://learn.microsoft.com/en-us/powershell/module/microsoft.graph.authentication/get-mgenvironment?view=graph-powershell-1.0). Default: Global"
    )]
    [string]$Environment = "Global",
    [Parameter(
        HelpMessage="TenantId to connect to. Default: common"
    )]
    [string]$TenantId = "common",
    [Parameter(
        HelpMessage="If the script should attempt to login to MS Graph first. You may also login separately using 
        [Connect-MgGraph](https://learn.microsoft.com/en-us/powershell/module/microsoft.graph.authentication/connect-mggraph?view=graph-powershell-1.0). Default: True"
    )]
    [bool]$Login = $true,
    [Parameter(
        HelpMessage="If the script should logout from MS Graph at the end. You may also logout separately using 
        [Disconnect-MgGraph](https://learn.microsoft.com/en-us/powershell/module/microsoft.graph.authentication/disconnect-mggraph?view=graph-powershell-1.0). Default: True"
    )]
    [bool]$Logout = $true,
    [Parameter(
        HelpMessage="-WhatIf=true will run the script in a what-if mode and only log the updated policies `
        without actually updating them in Entra ID. Run with -WhatIf=false to update the policies. Default: False"
    )]
    [bool]$WhatIf = $false
)
Write-Host "Script starting. Confirming environment setup..."
Import-Module $PSScriptRoot\Modules\SetPolicyOnApp.psm1 -Force
Import-Module $PSScriptRoot\Modules\Application.psm1 -Force

Set-DebugAppManagementPolicies($DebugPreference)
Set-DebugApplication($DebugPreference)

Write-Debug "Checking if Microsoft.Graph module is installed..."
Assert-ModuleExists -ModuleName "Microsoft.Graph" -InstallLink "https://learn.microsoft.com/en-us/powershell/microsoftgraph/installation?view=graph-powershell-1.0"

$RequiredScopes = "Policy.Read.All Application.ReadWrite.All Policy.ReadWrite.ApplicationConfiguration"

if ($false -eq $Login) {
    Write-Warning "-Login Set to `$false`. Ensure the Connect-MgGraph command has been run with the following required scopes for this script: $RequiredScopes."
}

# Set the Environment for the connections.
Set-ExecutionEnvironment -Environment $Environment

if ($true -eq $Login) {
    # Login to MS Graph interactively
    Start-Login -TenantId $TenantId -RequiredScopes $RequiredScopes
}

if ($true -eq $WhatIf) {
    Write-Warning "What-If mode in ON"
    Write-Warning "The script was run without -WhatIf parameter or with '-WhatIf `$true`'."
    Write-Warning "The script will not update the tenant application management policy in Entra ID but will log the updated policy."
    Write-Warning "To update the policy in Entra ID, re-run the script with What-If mode off using param '-WhatIf `$false`'."
}
$defaultDisabledPolicyName = "Identifier URI addition exemption"
$application = Get-AppByAppId -AppId $AppId
$appObjId = $application.id

# Get the existing policy for the App or the tenant policy if none exist.
$existingPolicy = Get-AppManagementPolicyForApp -AppId $appObjId
if ($null -eq $existingPolicy){
    Write-Message "The application does not have any custom app management policy assigned. No further action is required."
    if ($true -eq $Logout) {
        Start-Logout
    }
    Exit
} else {
    if("enabled" -eq $existingPolicy.restrictions.applicationRestrictions.identifierUris.nonDefaultUriAddition.state){
        Write-Message "The application is already enrolled in the NonDefaultUriAddition restriction. No further action is required."
        if ($true -eq $Logout) {
            Start-Logout
        }
        Exit
    }
}

# App is assigned to default policy. Simply unassign.
if ($defaultDisabledPolicyName -eq $existingPolicy.displayName) {
    Remove-AppManagementPolicyAssignment -AppId $appObjId -PolicyId $existingPolicy.id -WhatIf $WhatIf
} else {
    # App was assigned a different custom policy. Update to enable the nondDefaultUriAddition restriction.
    $existingPolicy.restrictions.applicationRestrictions.identifierUris.nonDefaultUriAddition.state = "enabled"
    Update-ApplicationManagementPolicy -PolicyType "Custom" -Policy $existingPolicy -WhatIf $WhatIf
}

if ($true -eq $Logout) {
    Start-Logout
}

if ($true -eq $WhatIf) {
    Write-Warning "What-If mode is ON"
    Write-Warning "The script was run with no -WhatIf parameter or with '-WhatIf `$true`'."
    Write-Warning "The application was not granted an exemption in Entra ID."
}

Write-Message "Exemption successfully removed from app with app ID {$AppId}. This application can no longer have custom identifier URIs added to it.”
# SIG # Begin signature block
# MIIFxQYJKoZIhvcNAQcCoIIFtjCCBbICAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCB/siynbW4hRTH9
# RtGUgMLHOc28LmVixbIIo7opnC7icaCCAzowggM2MIICHqADAgECAhBuQViVGZw2
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
# gjcCARUwLwYJKoZIhvcNAQkEMSIEIBIFra9U5jWlfmKqxwRuIkVkatUvDTbA8jo3
# EY/3/KKgMA0GCSqGSIb3DQEBAQUABIIBAEd+mISdHgLHRg84FPchjw2DOzj0McJm
# eSSIVpefZFCwp+PBCikqSvprkkk8NdYanVeHGvsnvaRV+ZeGyG87jSkE5ByASZyW
# GWsOxIRZTx67243iMeOoiAaSO4hPfuJGl0euTkakaMporwhibJSFLxQL8xvcrQk/
# 8V7hKQWoRpWli3jbMlwuEpnJG7Rq5tnE03yoKLcU8i1e4zza9xdYSJZFi98pnFqo
# JtZbckjfrXY7p35aQOI6Z7Ymqa5i0dbwk/PnXmmUQfvOoNGnMeyUsF3795p4YxHV
# aQVjmRBE5E8anXKa6Ur1hIQtq+I4cwIv92Hk9S+yK3bj1e3D5JgEpCA=
# SIG # End signature block
