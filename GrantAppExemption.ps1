#Requires -Version 7.2.0

<#
.SYNOPSIS
    Powershell script to exempt an Application from the IdentifierUris NonDefaultUriAddition restriction.
.DESCRIPTION
    A recent Entra security update enables Tenant Admins to restrict the addition of custom Identifier URIs to applications.
    However, there may be scenarios where an application requires the ability to add custom identifier URIs. This script simplifies the process of granting an 
    exemption to an Application from the nonDefaultUriAddition AppManagementPolicy enforcement.

    Applications are exempted from the NonDefaultUri restriction when they have an assigned custom AppManagementPolicy with the nonDefaultUriAddition property set to 'disabled'.
    This script assigns a new AppManagementPolicy to the Application with the nonDefaultUriAddition property set to 'disabled' to exempt the Application from the restriction.
    It does not modify any existing AppManagementPolicies as AppManagementPolicies can be assigned to more than one Application. This ensures that the exemption is 
    granted only to the Application specified by the user. All values from the existing assigned policy are copied to the new policy to ensure the application policy remains consistent
    for other assigned applications.

    This script performs the following modifications to the tenant:
    1. Creates a new AppManagementPolicy with the nonDefaultUriAddition property set to 'disabled' copied from the existing policy (if it exists).
    2. Removes the existing AppManagementPolicy from the Application.
    3. Assigns the new AppManagementPolicy to the Application.

    Prerequisites for executing the script:
    - PowerShell 7.2.0 or later
    - Microsoft.Graph module
    - Minimum required roles for Admin performing this script:
        - Cloud Application Administrator
.PARAMETER AppId
    The Application AppId to exempt from the IdentifierUris NonDefaultUriAddition restriction. Required.
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
.PARAMETER Restriction
    The restriction to exempt: 'nonDefaultUriAddition' or 'uriAdditionWithoutUniqueTenantIdentifier'.
    Default: uriAdditionWithoutUniqueTenantIdentifier
.EXAMPLE
    GrantAppExemption.ps1 -AppId "12345678-1234-1234-1234-123456789012" -WhatIf $true
    To run the script and review the log output without updating any objects in the tenant. Used to verify the script actions before committing the changes to the tenant.
.EXAMPLE
    GrantAppExemption.ps1 -AppId "12345678-1234-1234-1234-123456789012" -WhatIf $false
    To run the script and assign a new IdentifierUri Restriction exempt AppManagementPolicy to the App. This will unassign the currently assigned policy if it exists.
.EXAMPLE
    GrantAppExemption.ps1 -AppId "12345678-1234-1234-1234-123456789012" -TenantId "961581b0-b5e9-4872-a9cf-83a2a9f975ab"
    To login to the specified tenant. This is used if the user has multiple tenants and needs to specify which tenant to run the script against. Cannot be used with -Login $false as this flag overrides the -TenantId functionality.
.EXAMPLE
    GrantAppExemption.ps1 -AppId "12345678-1234-1234-1234-123456789012" -Debug
    To run the script and view the detailed debug output. Used for troubleshooting any errors.
.EXAMPLE
    GrantAppExemption.ps1 -AppId "12345678-1234-1234-1234-123456789012" -WhatIf $true -Logout $false

    GrantAppExemption.ps1 -AppId "12345678-1234-1234-1234-123456789012" -WhatIf $false -Login $false

    To run the script in both -WhatIf modes without repeating the login flow.
.EXAMPLE
    GrantAppExemption.ps1 -AppId "12345678-1234-1234-1234-123456789012" -Restriction "nonDefaultUriAddition" -WhatIf $true
    To run the script and review the log output without updating any objects in the tenant for the specified restriction.
.NOTES
    Author: Zachary Allison
    Date:   06 Dec 2024
#>
[CmdletBinding()]
param(
    [Parameter(
        HelpMessage="The Application AppId to assign exemption to. Required.",
        Mandatory = $true
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
    [bool]$WhatIf = $false,
    [Parameter(
        HelpMessage="The restriction to exempt: 'nonDefaultUriAddition' or 'uriAdditionWithoutUniqueTenantIdentifier'. Default: uriAdditionWithoutUniqueTenantIdentifier"
    )]
    [ValidateSet("uriAdditionWithoutUniqueTenantIdentifier", "nonDefaultUriAddition")]
    [string]$Restriction = "uriAdditionWithoutUniqueTenantIdentifier"
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

try {
    # Get the existing policy for the App or the tenant policy if none exist.
    $oldPolicy = Get-AppManagementPolicyForApp -AppId $appObjId

    if ($null -ne $oldPolicy) {
        $RestrictionObj = $oldPolicy.restrictions.applicationRestrictions.identifierUris.$Restriction;

        if ("disabled" -eq $RestrictionObj.state) {
            Write-Warning "The application is already exempted from the '$Restriction' restriction. No further action is required."

            Invoke-Exit $Logout
            return
        }

        $oldPolicyId = $oldPolicy.id
        $oldPolicy.PSObject.Properties.Remove("id")
        $oldPolicy.displayName = $oldPolicy.displayName + " with Identifier URI addition exemption"
        $oldPolicy.description = "This policy was duplicated from policy with id $oldPolicyId. An exemption to the restriction blocking the addition of non-default identifier URIs was added."
        
        # DisplayName should not exceed 256 characters
        if ($oldPolicy.displayName.Length -gt 256) {
            $oldPolicy.displayName = $oldPolicy.displayName.Substring(0, 256)
        }

    }

    if ($null -eq $oldPolicy) {
        # Create an empty policy with the default disabled policy name
        $oldPolicy = New-CustomPolicyForAppId -AppId $appObjId -DisplayName $defaultDisabledPolicyName
    }

    # Assign to existing policy if it already exists
    $newPolicy = Get-ExistingNonDefaultUriCustomPolicy -PolicyName $defaultDisabledPolicyName

    if ($null -eq $newPolicy) {
        # Create new policy with nondefaultUriAddition disabled
        $newPolicy = Invoke-CreateNewPolicyWithDisabledRestriction -Policy $oldPolicy -RestrictionTypeName $Restriction -WhatIf $WhatIf
    }

    # Assign Policy to App
    Invoke-AssignPolicyToApp -AppId $appObjId -Policy $newPolicy -OldPolicyId $oldPolicyId -WhatIf $WhatIf

} catch {
    Write-Error "An error occurred while processing the application exemption."
    Write-Error "Error details: $($_.Exception.Message)"

    Invoke-Exit $Logout
    return
}

if ($true -eq $WhatIf) {
    Write-Warning "What-If mode is ON"
    Write-Warning "The application with app Id '$AppId' was not granted an exemption in Entra ID."

    Invoke-Exit $Logout
    return
}

Write-Message "Exemption from restriction '$Restriction' successfully granted to application with app Id '$AppId'. This application can now have custom identifier URIs added to it."

Invoke-Exit $Logout
# SIG # Begin signature block
# MIIFxQYJKoZIhvcNAQcCoIIFtjCCBbICAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCBsKx/tFd//nZep
# ANfiQjQHY3/eJmn1x0h/wYPKV4qFcKCCAzowggM2MIICHqADAgECAhBuQViVGZw2
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
# gjcCARUwLwYJKoZIhvcNAQkEMSIEIGbbfC1IA7109ROrlMH2N4ymce6Kri1SReiC
# Kfjdv5HeMA0GCSqGSIb3DQEBAQUABIIBAD75Z5Y9BhDlffCoqEtUcpRlgxv5CSlE
# cI/fy+qnzHre0ezO/+cP617B2XDBlB2T1+WIRjIIg9KHIpb7c+hNWkRk3sAhfXof
# 4k3CFX5N9e+XYRlGKrfHcPw9rNf0adYBQsYPyo27ASxll4BGJarF2fFP69EDCUgY
# FjjULUiB0QF1E4JasbygmazX5k9l3OcmtQbBtC0P4Zz3fhhbjWstIMqtVrbRHoxy
# ndFF4eHfvxuyILSewIORiMvwlg85/KeVfF2NovQJYhDT37IPKjp3y77oPCchsAbj
# 0396faI6JGmi20qcbMmcNTtqdP79vXh/Dvnuu1Va/l3qb9+Sjohpjno=
# SIG # End signature block
