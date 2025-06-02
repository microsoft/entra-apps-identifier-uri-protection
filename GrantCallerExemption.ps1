#Requires -Version 7.2.0

<#
.SYNOPSIS
    Powershell script to grant an exemption to the specified User or ServicePrincipal from the TenantAppManagementPolicy nonDefaultUriAddition enforcement.
.DESCRIPTION
    A recent Entra security update enables Tenant Admins to block app owners from adding new custom identifier URIs to their Entra app configurations.
    However, there may be existing business scenarios where an app owner may need to add custom identifier URIs on their app configuration.
    This script simplifies the process of granting an exemption to a User or ServicePrincipal from the nonDefaultUriAddition AppManagementPolicy enforcement.
    Take Caution, as this exemption is global within the tenant: exempt Users or ServicePrincipals can add custom identifier URIs to any app configuration they manage.

    Users and ServicePrincipals are exempted from the nonDefaultUriAddition AppManagementPolicy enforcement when they are assigned the CustomSecurityAttribute
    value defined in the TenantAppManagementPolicy under the applicationRestrictions.identifierUris.nonDefaultUriAddition.excludeActors.customSecurityAttributes attribute. The values
    in the TenantAppManagementPolicy must match exactly with the CustomSecurityAttribute value assigned to the User or ServicePrincipal.

    This script performs the following modifications to the tenant:
    1. Create an AttributeSet (if it does not exist) to hold the CustomSecurityAttribute
    2. Create a CustomSecurityAttribute (if it does not exist) with the specified String value
    3. Add the CustomSecurityAttribute (if not already present) to the TenantAppManagementPolicy applicationRestrictions.identifierUris.nonDefaultUriAddition.excludeActors.customSecurityAttributes property
    4. Assigns the CustomSecurityAttribute to the specified User or ServicePrincipal

    Prerequisites for executing the script:
    - PowerShell 7.2.0 or later
    - Microsoft.Graph module
    - Minimum required roles for Admin performing this script:
        - Attribute Assignment Administrator
        - Attribute Definition Administrator
        - Security Administrator
        - Cloud Application Administrator
.PARAMETER Id
    The User or ServicePrincipal ID to assign the CSA to. Required.
.PARAMETER CustomSecurityAttributeSet 
    The name of the AttributeSet the CustomSecurityAttribute belongs to. If the AttributeSet does not exist a new one will be created.
    Default: MicrosoftDefault
.PARAMETER CustomSecurityAttributeName
    The name of the CustomSecurityAttribute. If the CustomSecurityAttribute does not exist a new one will be created.
    Default: MicrosoftDefault
.PARAMETER CustomSecurityAttributeValue
    The string value of the CustomSecurityAttribute to assign. If the CustomSecurityAttribute value does not exist a new one will be created.
    Default: MicrosoftDefault
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
    GrantCallerExemption.ps1 -Id "12345678-1234-1234-1234-123456789012" -WhatIf $true
    To run the script and review the log output without updating any objects in the tenant. Used to verify the script actions before committing the changes to the tenant.
.EXAMPLE
    GrantCallerExemption.ps1 -Id "12345678-1234-1234-1234-123456789012" -WhatIf $false
    To run the script and assign the default exempt CustomSecurityAttribute to the User or ServicePrincipal. This will also create a default AttributeSet and CustomSecurityAttribute if they do not exist.
.EXAMPLE
    GrantCallerExemption.ps1 -Id "12345678-1234-1234-1234-123456789012" -TenantId "961581b0-b5e9-4872-a9cf-83a2a9f975ab"
    To login to the specified tenant. This is used if the user has multiple tenants and needs to specify which tenant to run the script against. Cannot be used with -Login $false as this flag overrides the -TenantId functionality.
.EXAMPLE
    GrantCallerExemption.ps1 -Id "12345678-1234-1234-1234-123456789012" -CustomSecurityAttributeSet "MyAttributeSet" -CustomSecurityAttributeName "MyCustomSecurityAttribute" -CustomSecurityAttributeValue "MyExistingValue"
    To run the script and assign the specified CustomSecurityAttribute to the principal. If the CustomSecurityAttribute does not exist, it will be created. The CustomSecurityAttributeValue must be of type 'String'.
.EXAMPLE
    GrantCallerExemption.ps1 -Id "12345678-1234-1234-1234-123456789012" -Debug
    To run the script and view the detailed debug output. Used for troubleshooting any errors.
.EXAMPLE
    GrantCallerExemption.ps1 -Id "12345678-1234-1234-1234-123456789012" -WhatIf $true -Logout $false

    GrantCallerExemption.ps1 -Id "12345678-1234-1234-1234-123456789012" -WhatIf $false -Login $false

    To run the script in both -WhatIf modes without repeating the login flow.
.NOTES
    Author: Zachary Allison
    Date:   12 Nov 2024
#>
[CmdletBinding()]
param(
    [Parameter(
        HelpMessage="The User or ServicePrincipal object ID to assign the CustomSecurityAttribute to. Mandatory.",
        Mandatory=$true
    )]
    [string]$Id,
    [Parameter(
        HelpMessage="The name of the AttributeSet. Default: AppManagementPolicy"
    )]
    [string]$CustomSecurityAttributeSet = "AppManagementPolicy",
    [Parameter(
        HelpMessage="The name of the existing AttributeSet for the CustomSecurityAttribute. Default: NonDefaultUriAddition"
    )]
    [string]$CustomSecurityAttributeName = "NonDefaultUriAddition",
    [Parameter(
        HelpMessage="The value of the CustomSecurityAttribute. Default: Exempt"
    )]
    [string]$CustomSecurityAttributeValue = "Exempt",
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
Import-Module $PSScriptRoot\Modules\SetCustomSecurityAttribute.psm1 -Force
Set-DebugCustomSecurityAttributes($DebugPreference)

Write-Debug "Checking if Microsoft.Graph module is installed..."
Assert-ModuleExists -ModuleName "Microsoft.Graph" -InstallLink "https://learn.microsoft.com/en-us/powershell/microsoftgraph/installation?view=graph-powershell-1.0"

$RequiredScopes = "Policy.Read.All Policy.ReadWrite.ApplicationConfiguration CustomSecAttributeDefinition.Read.All CustomSecAttributeDefinition.ReadWrite.All CustomSecAttributeAssignment.ReadWrite.All User.ReadWrite.All Application.ReadWrite.All"

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

# Get the Principal type and ensure the object exists.
$principalType = Invoke-GetPrincipalType -PrincipalId $Id

if ($null -eq $principalType) {
    Write-Debug "Unable to find principal object in tenant. Exiting."
    Write-Error "Principal $Id not found in tenant $TenantId. Unable to assign CustomSecurityAttribute to non-existent principal."
    if ($true -eq $Logout) {
        Start-Logout
    }
    Exit
}

# Create AttributeSet, CSA, and CSAExemption on the defaultTenantPolicy if they do not exist
Invoke-EnsureCustomSecurityAttributeObjects -attributeSetName $CustomSecurityAttributeSet  `
                                            -csaName $CustomSecurityAttributeName `
                                            -csaValue $CustomSecurityAttributeValue `
                                            -whatIf $WhatIf

Write-Debug "All objects created successfully. Assigning CSA to Principal."

# Assign the CSA to the Principal
Add-CSAToPrincipal -attributeSetName $CustomSecurityAttributeSet  `
                   -csaName $CustomSecurityAttributeName `
                   -csaValue $CustomSecurityAttributeValue `
                   -principalId $Id `
                   -principalType $principalType `
                   -whatIf $WhatIf

if ($true -eq $Logout) {
    Start-Logout
}

if ($true -eq $WhatIf) {
    Write-Warning "What-If mode is ON"
    Write-Warning "The script was run with no -WhatIf parameter or with '-WhatIf `$true`'."
    Write-Warning "Tenant application management policy was not updated in Entra ID."
}

Write-Message -Message “Exemption successfully granted. Principal with ID {$Id} can now add custom identifier URIs to Entra applications.”
# SIG # Begin signature block
# MIIFxQYJKoZIhvcNAQcCoIIFtjCCBbICAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCAdly9EiSJYGNQV
# gBJXI7iRUw+Ch6NVceP+6J6Q0bBL+aCCAzowggM2MIICHqADAgECAhBuQViVGZw2
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
# gjcCARUwLwYJKoZIhvcNAQkEMSIEIPUy8sNwAkjc0AAvFXCSjr9u/fSHaDja7lV7
# TOskx8GLMA0GCSqGSIb3DQEBAQUABIIBAHpIyj5RVwhGsLBILWEVbnU/SxnKTYN9
# QQsTlcaO12iSYR3vQZTK6HbcCDSFfqYA0s4JGNXroALJ/G+MpDf/MVXy/Z55sT20
# WrQMcy8dD/LBLKirVnCGOmSOd2C3CzuiiLqlFRYJ2okDqwWs5iahfz6VB9TPVugA
# A3fvy5Zf+LuPgYJNm2HKIK5Ir1i8ReXwZNQvoi8Ap5dqCi9RbUc9SpHk6c6RXGfT
# EhZss3wmFuxM94CHGk9BlmVvKJcArYJaMuL+RqVaWiGaY+txWuD/KhEO4P8m+Uqc
# HTudnaEXu61xF6QwrwrnD5zdjaxT6NgK+qjO0wGdTHoga1fki+H9Ps4=
# SIG # End signature block
