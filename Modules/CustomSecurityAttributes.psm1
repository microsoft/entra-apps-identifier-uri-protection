[CmdletBinding()]
param()

Import-Module $PSScriptRoot\EntraIdCommon.psm1 -Force

function Set-DebugCustomSecurityAttributes {
    param (
        $DebugPref
    )

    $script:DebugPreference = $DebugPref

    # Set Debug preference on all imported modules
    Set-DebugEntraIdCommon($DebugPreference)
}

<#
.SYNOPSIS
Get the AttributeSet for the assoicated ID.

.PARAMETER attributeSetId
The id of the AttributeSet.
#>
function Get-AttributeSet {
    param (
        [string] $attributeSetId
    )

    try {
        Write-Debug "Getting AttributeSet with Name: $attributeSetId"
        $attributeSet = Get-MgDirectoryAttributeSet -AttributeSetId $attributeSetId
        if ($null -eq $attributeSet) {
            Write-Warning "AttributeSet not found: $attributeSetId"
        } else {
            Write-Debug "AttributeSet found: $($attributeSet | ConvertTo-Json -Depth 99)"
        }
        return $attributeSet
    } catch {
        Write-Error "Error encountered while trying to get AttributeSet with Name: $attributeSetId"
        Write-Error "Error details: $($_.Exception.Message)"
        return $null
    }
}

<#
.SYNOPSIS
Create a new String Value CustomSecurityAttribute. Defaults to a collection with predefined values only. Adds a default description.

.PARAMETER attributeSetName
The name of the attribute set

.PARAMETER whatIf
If set to true runs the command in 'whatIf' mode which does not create any resources. Defaults to true.
#>
function New-AttributeSet {
    param (
        [string] $attributeSetName,
        [bool] $whatIf = $true
    )

    Write-Host "Creating AttributeSet: $attributeSetName"
    $params = @{
        id = $attributeSetName
        description = "Auto-generated AttributeSet for $attributeSetName"
        maxAttributesPerSet = 25
    }

    Write-Debug "Parameters:"
    Write-DebugObject ($params | Select-Object -Property *)

    try {
        if ($true -eq $whatIf) {
            Write-Warning "What-If mode is ON. New AttributeSet is logged here"
            New-MgDirectoryAttributeSet -BodyParameter $params -ErrorAction Stop -WhatIf
        } else {
            New-MgDirectoryAttributeSet -BodyParameter $params -ErrorAction Stop
        }

        Write-Host "Created new AttributeSet: '$attributeSetName'"
    } catch {
        Write-Error "Failed to create AttributeSet: '$attributeSetName'"
        Write-Error "Error details: $($_.Exception.Message)"
        throw $_
    }
}

<#
.SYNOPSIS
Get the CustomSecurityAttribute for the assoicated ID.

.PARAMETER customSecurityAttributeId
The id of the customSecurityAttributeId. Expected format is `attributeName`_`csaName`.
#>
function Get-CustomSecurityAttribute {
    param (
        [string] $customSecurityAttributeId
    )

    try {
        Write-Debug "Getting CustomSecurityAttribute with name: '$customSecurityAttributeId'"
        
        $customSecurityAttribute = Get-MgDirectoryCustomSecurityAttributeDefinition `
            -CustomSecurityAttributeDefinitionId $customSecurityAttributeId `
            -ErrorAction Stop
        
        if ($null -eq $customSecurityAttribute) {
            Write-Warning "CustomSecurityAttribute not found: '$customSecurityAttributeId'"
        }
        
        return $customSecurityAttribute
    } catch {
        Write-Error "Error encountered while trying to get CustomSecurityAttribute with Name: '$customSecurityAttributeId'"
        Write-Error "Error details: $($_.Exception.Message)"
        throw $_
    }
}

<#
.SYNOPSIS
Truncates a CustomSecurityAttribute string to a specified maximum length and converts it to PascalCase.

.DESCRIPTION
This function ensures that a given CustomSecurityAttribute string does not exceed a specified maximum length.
If the string exceeds the limit, it is truncated. Additionally, the function converts the string
name to PascalCase for consistency.

.PARAMETER customSecurityAttributeStr
The string of the CustomSecurityAttribute to process.

.PARAMETER maxLength
The maximum allowed length for the CustomSecurityAttribute string. Defaults to 32 characters.

.EXAMPLE
Restrict-CustomSecurityAttributeStringLength -customSecurityAttributeStr "exampleAttributeName" -maxLength 20

This will truncate the string to 20 characters and convert it to PascalCase.

.NOTES
This function is useful for ensuring compliance with naming conventions and length restrictions
for CustomSecurityAttribute strings.
#>
function Set-CustomSecurityAttributeStringLength {
    param (
        [string] $customSecurityAttributeStr,
        [string] $strName = "CustomSecurityAttribute",
        [int] $maxLength = 32
    )

    # Truncate customSecurityAttributeStr to maxLength characters if it exceeds the limit
    if ($customSecurityAttributeStr.Length -gt $maxLength) {
        $customSecurityAttributeStr = $customSecurityAttributeStr.Substring(0, $maxLength)
        Write-Warning "The $strName was truncated to $maxLength characters: '$customSecurityAttributeStr'"
    }

    # Convert CSA Name to PascalCase, if not already in that format
    $customSecurityAttributeStr = $customSecurityAttributeStr.Substring(0,1).ToUpper() + $customSecurityAttributeStr.Substring(1)

    return $customSecurityAttributeStr
}

<#
.SYNOPSIS
Create a new String Value CustomSecurityAttribute. Defaults to a collection with predefined values only. Adds a default description.

.PARAMETER attributeSetName
The name of the existing attribute set to assign the CustomSecurityAttribute under.

.PARAMETER csaName
The name of the CustomSecurityAttribute.

.PARAMETER csaValue
The predefined value for the CustomSecurityAttribute.

.PARAMETER whatIf
If set to true runs the command in 'whatIf' mode which does not create any resources. Defaults to true.
#>
function New-StringValueCustomSecurityAttribute {
    param (
        [string] $attributeSetName,
        [string] $csaName,
        [string] $csaValue,
        [bool] $whatIf = $true
    )

    Write-Host "Creating CustomSecurityAttribute: '$csaName' with value: '$csaValue' under AttributeSet: '$attributeSetName'"

    $params = @{
        attributeSet = $attributeSetName
        description = "Auto-generated description for $csaName."
        isCollection = $true
        isSearchable = $true
        name = $csaName
        status = "Available"
        type = "String"
        usePreDefinedValuesOnly = $true
        allowedValues = @(
            @{
                id = $csaValue
                isActive = $true
            }
        )
    }

    Write-Debug "Parameters:"
    Write-DebugObject ($params | Select-Object -Property *)

    try {
        if ($true -eq $whatIf) {
            Write-Warning "What-If mode is ON. New CustomSecurityAttribute is logged here"
            New-MgDirectoryCustomSecurityAttributeDefinition -BodyParameter $params -ErrorAction Stop -WhatIf
        } else {
            New-MgDirectoryCustomSecurityAttributeDefinition -BodyParameter $params -ErrorAction Stop
        }

        Write-Host "Created new custom Security Attribute with ID: '$($result.id)'"
        Write-VerboseObject ($result | Select-Object -Property *)
    } catch {
        Write-Error "Failed to create CustomSecurityAttribute: '$csaName' under AttributeSet: '$attributeSetName'"
        Write-Error "Error details: $($_.Exception.Message)"
        throw $_
    }
}

<#
.SYNOPSIS
Activate a CustomSecurityAttribute.

.PARAMETER csa
The CustomSecurityAttribute to activate.

.PARAMETER whatIf
If set to true runs the command in 'whatIf' mode which does not create any resources. Defaults to true.
#>
function Update-ActivateCustomSecurityAttribute {
    param (
        $csa,
        [bool] $whatIf = $true
    )

    $params = @{
        status = "Available"
    }

    Write-Debug "Parameters:"
    Write-DebugObject ($params | Select-Object -Property *)

    try {
        if ($true -eq $whatIf) {
            Write-Warning "What-If mode is ON. Activating the CustomSecurityAttribute $($csa.name) {$($csa.id)}"
            Update-MgDirectoryCustomSecurityAttributeDefinition -CustomSecurityAttributeDefinitionId $csa.id -BodyParameter $params -ErrorAction Stop -WhatIf
        } else {
            Update-MgDirectoryCustomSecurityAttributeDefinition -CustomSecurityAttributeDefinitionId $csa.id -BodyParameter $params -ErrorAction Stop
        }
        Write-Host "Activated custom Security Attribute with Id: '$($csa.id)'"
        Write-VerboseObject ($result | Select-Object -Property *)
    } catch {
        Write-Error "Failed to activate CustomSecurityAttribute with Id: '$($csa.id)'"
        Write-Error "Error details: $($_.Exception.Message)"
        throw $_
    }
}

<#
.SYNOPSIS
Add the CustomSecurityAttribute to the principal.

.PARAMETER attributeSetName
The name of the existing attribute set to assign the CustomSecurityAttribute under.

.PARAMETER csaName
The name of the CustomSecurityAttribute.

.PARAMETER csaValue
The predefined value for the CustomSecurityAttribute.

.PARAMETER principalId
The object id of the principal to assign the CustomSecurityAttribute to.

.PARAMETER principalType
The type of the principal. Valid values are User and ServicePrincipal.

.PARAMETER whatIf
If set to true runs the command in 'whatIf' mode which does not create any resources. Defaults to true.
#>
function Add-CSAToPrincipal {
    param (
        [string] $attributeSetName,
        [string] $csaName,
        [string] $csaValue,
        [string] $principalId,
        [ValidateSet("User", "ServicePrincipal")]
        [string] $principalType,
        [bool] $whatIf
    )

    $params = @{
        customSecurityAttributes = @{
            $attributeSetName = @{
                "@odata.type" = "#Microsoft.DirectoryServices.CustomSecurityAttributeValue"
                $csaName = @($csaValue)
            }
        }
    }

    Write-Debug "Parameters:"
    Write-DebugObject ($params | Select-Object -Property *)

    try {
        if ("ServicePrincipal" -eq $principalType) {
            if ($true -eq $whatIf) {
                Write-Warning "What-If mode is ON. New ServicePrincipal is logged here"
                Update-MgServicePrincipal -ServicePrincipalId $principalId -BodyParameter $params -ErrorAction Stop -WhatIf
            } else {
                Update-MgServicePrincipal -ServicePrincipalId $principalId -BodyParameter $params -ErrorAction Stop
            }
        } elseif ("User" -eq $principalType) {
            if ($true -eq $whatIf) {
                Write-Warning "What-If mode is ON. New User is logged here"
                Update-MgUser -UserId $principalId -BodyParameter $params -ErrorAction Stop -WhatIf
            } else {
                Update-MgUser -UserId $principalId -BodyParameter $params -ErrorAction Stop
            }
        }

        Write-Host "CustomSecurityAttribute added to ${principalType}: ${principalId}"
    } catch {
        Write-Error "Failed to add CustomSecurityAttribute to ${principalType}: ${principalId}"
        Write-Error "Error details: $($_.Exception.Message)"
        throw $_
    }
}

<#
.SYNOPSIS
Remove the CustomSecurityAttribute from the principal.

.PARAMETER attributeSetName
The name of the existing attribute set to assign the CustomSecurityAttribute under.

.PARAMETER csaName
The name of the CustomSecurityAttribute.

.PARAMETER csaValue
The predefined value for the CustomSecurityAttribute.

.PARAMETER principalId
The object id of the principal to assign the CustomSecurityAttribute to.

.PARAMETER principalType
The type of the principal. Valid values are User and ServicePrincipal.

.PARAMETER whatIf
If set to true runs the command in 'whatIf' mode which does not create any resources. Defaults to true.
#>
function Remove-CSAFromPrincipal {
    param (
        [string] $attributeSetName,
        [string] $csaName,
        [string] $csaValue,
        [string] $principalId,
        [ValidateSet("User", "ServicePrincipal")]
        [string] $principalType,
        [bool] $whatIf
    )
    $params = @{
        customSecurityAttributes = @{
            $attributeSetName = @{
                "@odata.type" = "#Microsoft.DirectoryServices.CustomSecurityAttributeValue"
                $csaName = @()
            }
        }
    }
    Write-Debug "Parameters:"
    Write-DebugObject ($params | Select-Object -Property *)

    try {
        if ("ServicePrincipal" -eq $principalType) {
            if ($true -eq $whatIf) {
                Write-Warning "What-If mode is ON. New ServicePrincipal is logged here"
                Update-MgServicePrincipal -ServicePrincipalId $principalId -BodyParameter $params -ErrorAction Stop -WhatIf
            } else {
                Update-MgServicePrincipal -ServicePrincipalId $principalId -BodyParameter $params -ErrorAction Stop
            }
        } elseif ("User" -eq $principalType) {
            if ($true -eq $whatIf) {
                Write-Warning "What-If mode is ON. New User is logged here"
                Update-MgUser -UserId $principalId -BodyParameter $params -ErrorAction Stop -WhatIf
            } else {
                Update-MgUser -UserId $principalId -BodyParameter $params -ErrorAction Stop
            }
        }

        Write-Host "Successfully removed CustomSecurityAttribute from ${principalType}: ${principalId}"
    } catch {
        Write-Error "Failed to remove CustomSecurityAttribute from ${principalType}: ${principalId}"
        Write-Error "Error details: $($_.Exception.Message)"
        throw $_
    }
}

<#
.SYNOPSIS
Retrieve a User by their ID.

.DESCRIPTION
This function fetches a User object from Microsoft Graph using their ID. It includes enhanced error handling to ensure any issues during the retrieval process are logged and handled appropriately.

.PARAMETER UserId
The ID of the User to retrieve.

.EXAMPLE
Get-User -UserId "12345678-1234-1234-1234-123456789012"

This retrieves the User with the specified ID.

.NOTES
Ensure that the Microsoft Graph module is imported and authenticated before calling this function.
#>
function Get-User {
    param (
        [Parameter(Mandatory = $true)]
        [string] $UserId
    )

    try {
        Write-Debug "Attempting to retrieve User with ID: $UserId"

        $user = Get-MgUser -UserId $UserId -ErrorAction Stop

        if ($null -eq $user) {
            Write-Warning "User not found for ID: $UserId"
            return $null
        }

        Write-Debug "User retrieved successfully: $($user | ConvertTo-Json -Depth 99)"
        return $user
    } catch {
        Write-Error "An error occurred while retrieving the User with ID: $UserId"
        Write-Error "Error details: $($_.Exception.Message)"
        throw $_
    }
}

<#
.SYNOPSIS
Retrieve a ServicePrincipal by its ID.

.DESCRIPTION
This function fetches a ServicePrincipal object from Microsoft Graph using its ID. It includes enhanced error handling to ensure any issues during the retrieval process are logged and handled appropriately.

.PARAMETER principalId
The ID of the ServicePrincipal to retrieve.

.EXAMPLE
Get-ServicePrincipal -principalId "12345678-1234-1234-1234-123456789012"

This retrieves the ServicePrincipal with the specified ID.

.NOTES
Ensure that the Microsoft Graph module is imported and authenticated before calling this function.
#>
function Get-ServicePrincipal {
    param (
        [Parameter(Mandatory = $true)]
        [string] $principalId
    )

    try {
        Write-Debug "Attempting to retrieve ServicePrincipal with ID: $principalId"

        $servicePrincipal = Get-MgServicePrincipal -ServicePrincipalId $principalId -ErrorAction Stop

        if ($null -eq $servicePrincipal) {
            Write-Warning "ServicePrincipal not found for ID: $principalId"
            return $null
        }

        Write-Debug "ServicePrincipal retrieved successfully: $($servicePrincipal | ConvertTo-Json -Depth 99)"
        return $servicePrincipal
    } catch {
        Write-Error "An error occurred while retrieving the ServicePrincipal with ID: $principalId"
        Write-Error "Error details: $($_.Exception.Message)"
        throw $_
    }
}
# SIG # Begin signature block
# MIIFxQYJKoZIhvcNAQcCoIIFtjCCBbICAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCCcJ78JTvwerhDa
# ahTnqTH1oVZYgVqphZUPfGjuujTA6qCCAzowggM2MIICHqADAgECAhBuQViVGZw2
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
# gjcCARUwLwYJKoZIhvcNAQkEMSIEILOBNTjTm76tHxEKPGRudcNl9nOqUNECBW0b
# w+9l2A8jMA0GCSqGSIb3DQEBAQUABIIBAKONWvC6Ns/XQ7BMKUzSc5lxuBzOqOSU
# gKw962QwijDyCP/etdEf8Q+gkKQyM7jUW82oEfY3jLQrvICo4qjHqEcpqHj24YzZ
# EK6+OKsYibFjS+52A81yvsZBIQJ4FjYtsmlOlJYq1fas9+D1/hX0rEZjY6TSXR/w
# Kgnbq8MIxjrQcDeQX8Amy82+1uKBFx26SgsI1bsi2qntc7a6BGUXKkktdoNcS5vq
# LTugt3K1pG3QrQPCmDTyDJFBTF6pgUo/ivJMAS3h4o0zs1dJRaIo6MYCkRZRftyE
# cwMxqrJda+c6Mfz1oPOJZx7Qp23m0s5s9PVQpX5Y7SirHlou9FFUQuA=
# SIG # End signature block
