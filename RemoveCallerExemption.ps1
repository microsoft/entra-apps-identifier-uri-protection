#Requires -Version 7.2.0

<#
.SYNOPSIS
    Powershell script to remove an exemption to the specified User or ServicePrincipal from the TenantAppManagementPolicy nonDefaultUriAddition enforcement.
.DESCRIPTION
    A recent Entra security update enables Tenant Admins to block app owners from adding new custom identifier URIs to their Entra app configurations.
    This script simplifies the process of revoking an existing exemption to a User or ServicePrincipal from the nonDefaultUriAddition AppManagementPolicy enforcement.

    Users and ServicePrincipals are exempted from the nonDefaultUriAddition AppManagementPolicy enforcement when they are assigned the CustomSecurityAttribute
    value defined in the TenantAppManagementPolicy under the applicationRestrictions.identifierUris.nonDefaultUriAddition.excludeActors.customSecurityAttributes attribute. The values
    in the TenantAppManagementPolicy must match exactly with the CustomSecurityAttribute value assigned to the User or ServicePrincipal.

    This script performs the following modifications to the tenant:
    1. Removes the CustomSecurityAttribute from the specified User or ServicePrincipal

    Prerequisites for executing the script:
    - PowerShell 7.2.0 or later
    - Microsoft.Graph module
    - Minimum required roles for Admin performing this script:
        - Attribute Assignment Administrator
        - Attribute Definition Administrator
        - Security Administrator
        - Cloud Application Administrator
.PARAMETER Id
    The User or ServicePrincipal ID to remove the CSA from. Required.
.PARAMETER CustomSecurityAttributeSet 
    The name of the AttributeSet the CustomSecurityAttribute belongs to.
    Default: MicrosoftDefault
.PARAMETER CustomSecurityAttributeName
    The name of the CustomSecurityAttribute.
    Default: MicrosoftDefault
.PARAMETER CustomSecurityAttributeValue
    The string value of the CustomSecurityAttribute to assign.
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
.PARAMETER Restriction
    The restriction under identifierUris where the CSA exemption will be removed. Valid values are "uriAdditionWithoutUniqueTenantIdentifier" and "nonDefaultUriAddition".
.EXAMPLE
RemoveCallerExemption.ps1 -Id "12345678-1234-1234-1234-123456789012" -Restriction "nonDefaultUriAddition" -WhatIf $true
This example runs the script in What-If mode to simulate the removal of the CSA exemption for the specified principal under the "nonDefaultUriAddition" restriction.

.EXAMPLE
RemoveCallerExemption.ps1 -Id "12345678-1234-1234-1234-123456789012" -Restriction "uriAdditionWithoutUniqueTenantIdentifier" -WhatIf $false
This example removes the CSA exemption for the specified principal under the "uriAdditionWithoutUniqueTenantIdentifier" restriction and updates the tenant policy.

.EXAMPLE
RemoveCallerExemption.ps1 -Id "12345678-1234-1234-1234-123456789012" -CustomSecurityAttributeSet "MyAttributeSet" -CustomSecurityAttributeName "MyCustomSecurityAttribute" -CustomSecurityAttributeValue "MyValue" -Restriction "nonDefaultUriAddition" -WhatIf $true
This example simulates the removal of a CSA exemption with custom attribute set, name, and value under the "nonDefaultUriAddition" restriction.

.EXAMPLE
    # Example 1: Remove exemption for a ServicePrincipal
    Remove-CallerExemption -Id "12345678-1234-1234-1234-123456789abc" -Restriction "nonDefaultUriAddition"
    
    # This command removes the exemption for the ServicePrincipal with ID "12345678-1234-1234-1234-123456789abc" under the "nonDefaultUriAddition" restriction.

.EXAMPLE
    # Example 2: Remove exemption for a User with WhatIf mode enabled
    Remove-CallerExemption -Id "87654321-4321-4321-4321-cba987654321" -Restriction "uriAdditionWithoutUniqueTenantIdentifier" -WhatIf $true

    # This command simulates the removal of the exemption for the User with ID "87654321-4321-4321-4321-cba987654321" under the "uriAdditionWithoutUniqueTenantIdentifier" restriction without making actual changes.

.EXAMPLE
    # Example 3: Remove exemption with custom TenantId and environment
    Remove-CallerExemption -Id "11223344-5566-7788-99aa-bbccddeeff00" -Restriction "nonDefaultUriAddition" -TenantId "mytenant.onmicrosoft.com" -Environment "USGovernment"

    # This command removes the exemption for the principal with ID "11223344-5566-7788-99aa-bbccddeeff00" under the "nonDefaultUriAddition" restriction in the specified tenant and environment.
#>
[CmdletBinding()]
param(
    [Parameter(
        HelpMessage="The User or ServicePrincipal object ID to remove the CustomSecurityAttribute from. Mandatory.",
        Mandatory=$true
    )]
    [string]$Id,
    [Parameter(
        HelpMessage="Specifies the type of restriction to remove exemption from. Supported values are: nonDefaultUriAddition, uriAdditionWithoutUniqueTenantIdentifier. Default: uriAdditionWithoutUniqueTenantIdentifier"
    )]
    [ValidateSet("nonDefaultUriAddition", "uriAdditionWithoutUniqueTenantIdentifier")]
    [string]$Restriction = "uriAdditionWithoutUniqueTenantIdentifier",
    [Parameter(
        HelpMessage="The name of the AttributeSet. Default: AppManagementPolicy"
    )]
    [string]$CustomSecurityAttributeSet = "AppManagementPolicy",
    [Parameter(
        HelpMessage="The name of the existing AttributeSet for the CustomSecurityAttribute. Default: Matches the Restriction parameter value."
    )]
    [string]$CustomSecurityAttributeName = $Restriction,
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

try {
    # Get the Principal type and ensure the object exists.
    $principalType = Invoke-GetPrincipalType -PrincipalId $Id

    if ($null -eq $principalType) {
        Write-Error "Principal $Id not found in tenant $TenantId. Unable to remove CustomSecurityAttribute from non-existent principal."

        Invoke-Exit $Logout
        return
    }

    $CustomSecurityAttributeSet = Set-CustomSecurityAttributeStringLength `
        -customSecurityAttributeStr $CustomSecurityAttributeSet `
        -strName "CustomSecurityAttributeSet"

    $CustomSecurityAttributeName = Set-CustomSecurityAttributeStringLength `
        -customSecurityAttributeStr $CustomSecurityAttributeName `
        -strName "CustomSecurityAttributeName"

    # Remove the CSA from the Principal
    Remove-CSAFromPrincipal `
        -attributeSetName $CustomSecurityAttributeSet `
        -csaName $CustomSecurityAttributeName `
        -csaValue $CustomSecurityAttributeValue `
        -principalId $Id `
        -principalType $principalType `
        -whatIf $WhatIf

} catch {
    Write-Error "An error occurred while processing the script."
    Write-Error "Error details: $($_.Exception.Message)"
    
    Invoke-Exit $Logout
    return
}

if ($true -eq $WhatIf) {
    Write-Warning "What-If mode is ON"
    Write-Warning "The script was run with '-WhatIf `$true`'."
    Write-Warning "No exemption was removed from the caller principal with ID '$Id' in Entra ID."

    Invoke-Exit $Logout
    return
}

Write-Message -Message "Exemption from restriction '$Restriction' successfully removed. Principal with ID {$Id} can no longer add custom identifier URIs to Entra applications."

Invoke-Exit $Logout
# SIG # Begin signature block
# MIIFxQYJKoZIhvcNAQcCoIIFtjCCBbICAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCAHZMLmU5W6RH5M
# xdtRveOLe5DTNDdR+Nf8OZ0k69R4RqCCAzowggM2MIICHqADAgECAhBuQViVGZw2
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
# gjcCARUwLwYJKoZIhvcNAQkEMSIEIDOjtoSRECG4fnQL149yCyDbmt88horCIyca
# dcAk3M5oMA0GCSqGSIb3DQEBAQUABIIBAEioAuhk3x07CST7r5lA1BrcXs0z8hQR
# T8F11aJqIs+JNiII9Nc/IbPU70lowUKxPqXH7khqRMC04eLiYc+mkBfNyHhMT3Sq
# 7G8EqojF0/lC74YjuzZX1UlDl11v/gSfBDwuswT7ENnibYSadUGPhwpl2cre64WT
# 9SPEsTgZjPf/uBjkYvcgdwRnrsmdwWWUtuTihm2+DexB99xfPpXNeKjCgr0c9R+5
# Qc5pTx0g7Hv5voXhI6iYEOb3LhVd3BDXZ7KP/97+2JowHmJYxYUUL9+ARcKPPWUk
# gdKxY6IyB5bdwiqGSs7IimuYk6GIkfIWRvPZROvRnFfED8QipmI1D+o=
# SIG # End signature block
