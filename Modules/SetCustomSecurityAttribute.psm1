[CmdletBinding()]
param()

Import-Module $PSScriptRoot\CustomSecurityAttributes.psm1 -Force

Import-Module $PSScriptRoot\AppManagementPolicies.psm1 -Force

function Set-DebugSetCustomSecurityAttributes {
    param (
        $DebugPref
    )

    $script:DebugPreference = $DebugPref

    # Set Debug preference on all imported modules
    Set-DebugEntraIdCommon($DebugPreference)
}

<#
.SYNOPSIS
Determine the type of a principal (User or ServicePrincipal) based on its ID.

.DESCRIPTION
This function checks whether the provided Principal ID corresponds to a User or a ServicePrincipal in Microsoft Graph. It includes enhanced error handling to ensure any issues during the retrieval process are logged and handled appropriately.

.PARAMETER PrincipalId
The ID of the principal to check.

.EXAMPLE
Invoke-GetPrincipalType -PrincipalId "12345678-1234-1234-1234-123456789012"

This checks whether the provided Principal ID corresponds to a User or a ServicePrincipal.

.NOTES
Ensure that the Microsoft Graph module is imported and authenticated before calling this function.
#>
function Invoke-GetPrincipalType {
    param (
        [Parameter(Mandatory = $true)]
        [string] $PrincipalId
    )

    try {
        Write-Debug "Checking if the supplied Principal ID is a User."
        $user = Get-User -UserId $PrincipalId -ErrorAction Stop

        if ($null -ne $user) {
            Write-Debug "Principal ID corresponds to a User."
            return "User"
        }
    } catch {
        Write-Warning "An error occurred while checking if the Principal ID is a User: $($_.Exception.Message)"
    }

    try {
        Write-Debug "Checking if the supplied Principal ID is a ServicePrincipal."
        $servicePrincipal = Get-ServicePrincipal -principalId $PrincipalId -ErrorAction Stop

        if ($null -ne $servicePrincipal) {
            Write-Debug "Principal ID corresponds to a ServicePrincipal."
            return "ServicePrincipal"
        }
    } catch {
        Write-Warning "An error occurred while checking if the Principal ID is a ServicePrincipal: $($_.Exception.Message)"
    }

    Write-Warning "Principal ID does not correspond to a User or ServicePrincipal."
    return $null
}

<#
.SYNOPSIS
Ensure that the necessary Custom Security Attribute objects exist and are properly configured.

.DESCRIPTION
This function validates the existence of an AttributeSet and a CustomSecurityAttribute (CSA). If they do not exist, it creates them. Additionally, it ensures that the CSA is applied to the default tenant policy with the appropriate exemptions under the specified restriction type.

.PARAMETER attributeSetName
The name of the AttributeSet to validate or create.

.PARAMETER csaName
The name of the CustomSecurityAttribute to validate or create.

.PARAMETER csaValue
The value of the CustomSecurityAttribute to validate or create.

.PARAMETER RestrictionTypeName
The type of restriction under which to apply the CSA exemption. Valid values are "uriAdditionWithoutUniqueTenantIdentifier" and "nonDefaultUriAddition".

.PARAMETER whatIf
If set to true, the function will simulate the operations without making any changes.

.EXAMPLE
Invoke-CheckAndAddCustomSecurityAttributeExemption -attributeSetName "MyAttributeSet" -csaName "MyCSA" -csaValue "MyValue" -RestrictionTypeName "nonDefaultUriAddition" -whatIf $true

This will validate or create the AttributeSet and CSA, and ensure the CSA is applied to the default tenant policy under the "nonDefaultUriAddition" restriction type, without making any actual changes.

.NOTES
Ensure that the Microsoft Graph module is imported and authenticated before calling this function.
#>
function Invoke-CheckAndAddCustomSecurityAttributeExemption {
    param (
        [Parameter(Mandatory = $true)]
        [string] $attributeSetName,

        [Parameter(Mandatory = $true)]
        [string] $csaName,

        [Parameter(Mandatory = $true)]
        [string] $csaValue,

        [Parameter(Mandatory = $true)]
        [ValidateSet("uriAdditionWithoutUniqueTenantIdentifier", "nonDefaultUriAddition")]
        [string] $RestrictionTypeName,

        [Parameter(Mandatory = $false)]
        [bool] $whatIf = $false
    )

    try {
        # Validate input parameters
        Write-Debug "Validating input parameters."
        if (-not $attributeSetName) {
            throw [System.ArgumentException] "CustomSecurityAttributeSetName is required."
        }

        if (-not $csaName) {
            throw [System.ArgumentException] "CustomSecurityAttributeName is required."
        }

        if (-not $csaValue) {
            throw [System.ArgumentException] "CustomSecurityAttributeValue is required."
        }

        if (-not $RestrictionTypeName) {
            throw [System.ArgumentException] "RestrictionTypeName is required."
        }

        # Check and create AttributeSet if necessary
        Write-Debug "Getting the attribute set for the CSA."
        $attributeSet = Get-AttributeSet -attributeSetId $attributeSetName

        if ($null -eq $attributeSet) {
            Write-Debug "AttributeSet not found. Creating new AttributeSet."
            New-AttributeSet -attributeSetName $attributeSetName -whatIf $whatIf
        } else {
            Write-Debug "AttributeSet exists. Proceeding."
        }

        # Check and create CustomSecurityAttribute if necessary
        $csaId = "$attributeSetName`_$csaName"
        
        Write-Debug "Checking for CustomSecurityAttribute with ID: $csaId."
        $csa = Get-CustomSecurityAttribute -customSecurityAttributeId $csaId

        if ($null -eq $csa) {
            Write-Debug "CSA not found. Creating new CSA."
            New-StringValueCustomSecurityAttribute `
                -attributeSetName $attributeSetName `
                -csaName $csaName `
                -csaValue $csaValue `
                -whatIf $whatIf
        } elseif ("Deprecated" -eq $csa.status) {
            Write-Warning "CustomSecurityAttribute {$($csa.name)} is currently 'Deprecated'. Setting the status to 'Available'."
            Update-ActivateCustomSecurityAttribute -csa $csa -WhatIf $whatIf
        } else {
            Write-Debug "CustomSecurityAttribute exists. Proceeding."
        }

        # Check and apply CSA exemption to the default tenant policy
        Write-Debug "Retrieving the default tenant application management policy."
        $defaultTenantAppManagementPolicy = Get-TenantApplicationManagementPolicy
        
        $csaExemptionApplied = Invoke-CheckCSAExemptionsOnPolicy `
            -Policy $defaultTenantAppManagementPolicy `
            -CsaId $csaId `
            -RestrictionTypeName $RestrictionTypeName

        if (-not $csaExemptionApplied) {
            Write-Debug "CSAExemption not found on Default Tenant policy under restriction type: $RestrictionTypeName. Adding exemption."
            
            $newCsaExemption = @{
                "@odata.type" = "#microsoft.graph.customSecurityAttributeStringValueExemption"
                id = $csaId
                operator = "equals"
                value = $csaValue
            }
            
            Invoke-AddCSAExemptionToIdentifierUrisRestriction `
                -Policy $defaultTenantAppManagementPolicy `
                -CsaExemption $newCsaExemption `
                -RestrictionTypeName $RestrictionTypeName `
                -whatIf $whatIf
        }

    } catch {
        Write-Error "An error occurred in Invoke-CheckAndAddCustomSecurityAttributeExemption."
        Write-Error "Error details: $($_.Exception.Message)"
        throw $_  # Re-throw the exception for upstream handling
    }
}

<#
.SYNOPSIS
Checks if a Custom Security Attribute (CSA) exemption is already applied to a given policy.

.DESCRIPTION
This function iterates through the existing CSA exemptions in the provided policy to determine if a specific CSA exemption, identified by its ID, is already applied. It supports checking under different restriction types specified by the RestrictionTypeName parameter.

.PARAMETER Policy
The application management policy to check for the CSA exemption.

.PARAMETER CsaId
The ID of the CSA exemption to check for.

.PARAMETER RestrictionTypeName
The type of restriction under which to check for the CSA exemption. Valid values are "uriAdditionWithoutUniqueTenantIdentifier" and "nonDefaultUriAddition".

.EXAMPLE
Invoke-CheckCSAExemptionsOnPolicy -Policy $policy -CsaId "MyCSAId" -RestrictionTypeName "nonDefaultUriAddition"

This checks if the CSA exemption with ID "MyCSAId" is applied to the provided policy under the "nonDefaultUriAddition" restriction type.

.NOTES
Ensure that the policy object is properly initialized and contains the necessary structure before calling this function.
#>
function Invoke-CheckCSAExemptionsOnPolicy {
    param (
        [Parameter(Mandatory = $true)]
        [object] $Policy,

        [Parameter(Mandatory = $true)]
        [string] $CsaId,

        [Parameter(Mandatory = $true)]
        [ValidateSet("uriAdditionWithoutUniqueTenantIdentifier", "nonDefaultUriAddition")]
        [string] $RestrictionTypeName
    )

    try {
        # Validate input parameters
        Write-Debug "Validating input parameters."
        if (-not $Policy) {
            throw [System.ArgumentException] "Policy parameter is required."
        }

        if (-not $CsaId) {
            throw [System.ArgumentException] "CsaId parameter is required."
        }

        if (-not $RestrictionTypeName) {
            throw [System.ArgumentException] "RestrictionTypeName parameter is required."
        }

        # Check if the policy structure is properly initialized
        Write-Debug "Checking if the policy structure is properly initialized for restriction type: $RestrictionTypeName."
        if ($null -eq $Policy.applicationRestrictions -or
            $null -eq $Policy.applicationRestrictions.identifierUris -or
            $null -eq $Policy.applicationRestrictions.identifierUris.$RestrictionTypeName -or
            $null -eq $Policy.applicationRestrictions.identifierUris.$RestrictionTypeName.excludeActors -or
            $null -eq $Policy.applicationRestrictions.identifierUris.$RestrictionTypeName.excludeActors.customSecurityAttributes) {
            Write-Debug "Policy structure is not properly initialized for restriction type: $RestrictionTypeName. Returning false."
            return $false
        }

        # Iterate through the CSA exemptions to check for the specified ID
        Write-Debug "Iterating through CSA exemptions to check for ID: $CsaId under restriction type: $RestrictionTypeName."
        foreach ($csaExemption in $Policy.applicationRestrictions.identifierUris.$RestrictionTypeName.excludeActors.customSecurityAttributes) {
            if ($csaExemption.id -eq $CsaId) {
                Write-Debug "CSA exemption with ID $CsaId found under restriction type: $RestrictionTypeName."
                return $true
            }
        }

        Write-Debug "CSA exemption with ID $CsaId not found under restriction type: $RestrictionTypeName."
        return $false

    } catch {
        Write-Error "An error occurred in Invoke-CheckCSAExemptionsOnPolicy."
        Write-Error "Error details: $($_.Exception.Message)"
        throw $_  # Re-throw the exception for upstream handling
    } # End of try-catch block
} # End of function

<#
.SYNOPSIS
Adds a Custom Security Attribute (CSA) exemption to a specified restriction under identifierUris.

.DESCRIPTION
This function ensures that a CSA exemption is added to the specified restriction under identifierUris of the provided application management policy. It validates and initializes the necessary policy structure before applying the exemption.

.PARAMETER Policy
The application management policy to which the CSA exemption will be added.

.PARAMETER CsaExemption
The CSA exemption object to add to the policy.

.PARAMETER RestrictionTypeName
The restriction under identifierUris where the CSA exemption will be added. Valid values are "uriAdditionWithoutUniqueTenantIdentifier" and "nonDefaultUriAddition".

.PARAMETER whatIf
If set to true, the function will simulate the operation without making any changes.

.EXAMPLE
Invoke-AddCSAExemptionToIdentifierUrisRestriction -Policy $policy -CsaExemption $exemption -RestrictionTypeName "nonDefaultUriAddition" -whatIf $true

This will simulate adding the CSA exemption to the "nonDefaultUriAddition" restriction under identifierUris in the policy.

.NOTES
Ensure that the Microsoft Graph module is imported and authenticated before calling this function.
#>
function Invoke-AddCSAExemptionToIdentifierUrisRestriction {
    param (
        [Parameter(Mandatory = $true)]
        [object] $Policy,

        [Parameter(Mandatory = $true)]
        [hashtable] $CsaExemption,

        [Parameter(Mandatory = $true)]
        [ValidateSet("uriAdditionWithoutUniqueTenantIdentifier", "nonDefaultUriAddition")]
        [string] $RestrictionTypeName,

        [Parameter(Mandatory = $false)]
        [bool] $whatIf
    )

    try {
        # Validate input parameters
        Write-Debug "Validating input parameters."
        if (-not $Policy) {
            throw [System.ArgumentException] "Policy parameter is required."
        }

        if (-not $CsaExemption) {
            throw [System.ArgumentException] "CsaExemption parameter is required."
        }

        if (-not $RestrictionTypeName) {
            throw [System.ArgumentException] "RestrictionTypeName parameter is required."
        }

        # Initialize policy structure if necessary
        Write-Debug "Initializing policy structure for restriction: $RestrictionTypeName."
        if ($null -eq $Policy.applicationRestrictions) {
            $Policy.applicationRestrictions = @{ }
        }

        if ($null -eq $Policy.applicationRestrictions.identifierUris) {
            $Policy.applicationRestrictions.identifierUris = @{ }
        }

        if ($null -eq $Policy.applicationRestrictions.identifierUris.$RestrictionTypeName) {
            $Policy.applicationRestrictions.identifierUris.$RestrictionTypeName = @{ }
        }

        if ($null -eq $Policy.applicationRestrictions.identifierUris.$RestrictionTypeName.excludeActors) {
            $Policy.applicationRestrictions.identifierUris.$RestrictionTypeName.excludeActors = @{ }
        }

        if ($null -eq $Policy.applicationRestrictions.identifierUris.$RestrictionTypeName.excludeActors.customSecurityAttributes) {
            $Policy.applicationRestrictions.identifierUris.$RestrictionTypeName.excludeActors.customSecurityAttributes = [System.Collections.ArrayList]::new()
        }

        # Add the CSA exemption
        Write-Debug "Adding the CSA exemption to the restriction: $RestrictionTypeName."
        $Policy.applicationRestrictions.identifierUris.$RestrictionTypeName.excludeActors.customSecurityAttributes += $CsaExemption

        # Update the policy
        Write-Debug "Updating the application management policy."
        Update-ApplicationManagementPolicy -PolicyType "Tenant" -Policy $Policy -WhatIf ($whatIf -eq $true)

    } catch {
        Write-Error "An error occurred in Invoke-AddCSAExemptionToIdentifierUrisRestriction."
        Write-Error "Error details: $($_.Exception.Message)"
        throw $_  # Re-throw the exception for upstream handling
    }
}
# SIG # Begin signature block
# MIIFxQYJKoZIhvcNAQcCoIIFtjCCBbICAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCB3gFvs7VITefAe
# hvtUE74Xf2TOoyS9q2BAhMPZkk8gk6CCAzowggM2MIICHqADAgECAhBuQViVGZw2
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
# gjcCARUwLwYJKoZIhvcNAQkEMSIEIGp1IN01HDElHBnhknv1lmanOC9+3LhldA9x
# 16V2vEY0MA0GCSqGSIb3DQEBAQUABIIBALdY6LnsmuHGBRyCSpS+Yv0RU3zCVmNy
# G9n7p8t60OszJhI92IvFJzN4rfEDhtdn+g+WsaQOmuOZh/wiahIUFlKUQJJohpfZ
# eu0IN+gJWUHs6JbqGjnePRKVsZQCnG+FPgIh+DoQtOvF7iWEcI6iHdYEQy+RYlIo
# UQR8PP1X6lvXhx5VKMn+sNgMdxCZ04V2hvBnlF8rgYklqxG7ZTZk5etpvIvOsjzx
# VsyF3gNuaLpcz6XOplqrUdH/hOxExIY5M9VexcqOQCVVMJqbxmGFJGqUK8kPxH2w
# enUCm9Ghm5aGcSgcYyGr2twejvBISPZWP0SE8yNeLgn0yuTB7GM3We0=
# SIG # End signature block
