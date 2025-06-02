[CmdletBinding()]
param()

Import-Module $PSScriptRoot\EntraIdCommon.psm1 -Force

function Set-DebugCustomSecurityAttributes {
    param (
        $DebugPref
    )

    $script:DebugPreference = $DebugPref

    # Set Debug pref on all imported modules
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
        Write-Debug "Getting AttributeSet with Name: $attributeSet"
        $exception = $($attributeSet = Get-MgDirectoryAttributeSet -AttributeSetId $attributeSetId) 2>&1
        if ($null -ne $exception) {
            Write-Debug $exception
        }
        else {
            Write-Debug "AttributeSet found: $($attributeSet | ConvertTo-Json -Depth 99)"
        }
        return $attributeSet
    }
    catch {
        Write-Warning "Error encountered while trying to get AttributeSet with Name: $attributeSetId"
        Write-Warning $_.Exception.Message
    }
    return $null
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
    $attributeException = $null
    if ($true -eq $whatIf) {
        Write-Warning "What-If mode is ON. New AttributeSet is logged here"
        New-MgDirectoryAttributeSet  -BodyParameter $params -WhatIf
        $result = $params
    } else {
        $attributeException = $($result = New-MgDirectoryAttributeSet -BodyParameter $params) 2>&1
    }

    if ($null -ne $attributeException) {
        Write-CreationErrorAndExit -exception $attributeException -roles "Attribute Definition Administrator"
    }
    Write-Host "Created new AttributeSet $attributeSetName "
    Write-VerboseObject ($result | Select-Object -Property *)
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
        Write-Debug "Getting CustomSecurityAttribute with Name: $customSecurityAttributeId"
        $exception = $($customSecurityAttribute = Get-MgDirectoryCustomSecurityAttributeDefinition -CustomSecurityAttributeDefinitionId $customSecurityAttributeId) 2>&1
        if ($null -ne $exception) {
            Write-Debug $exception
        }
        return $customSecurityAttribute
    }
    catch {
        Write-Warning "Error encountered while trying to get CustomSecurityAttribute with Name: $customSecurityAttributeId"
        Write-Warning $_.Exception.Message
    }
    return $null
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
    Write-Host "Creating CustomSecurityAttribute: $csaName with value: $csaValue under AttributeSet: $attributeSetName"
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
    $result = $null
    $exception = $null
    if ($true -eq $whatIf) {
        Write-Warning "What-If mode is ON. New CustomSecurityAttribute is logged here"
        New-MgDirectoryCustomSecurityAttributeDefinition -BodyParameter $params -WhatIf
        $result = $params
    } else {
        $exception = $($result = New-MgDirectoryCustomSecurityAttributeDefinition -BodyParameter $params) 2>&1
    }

    if ($null -ne $exception) {
        Write-CreationErrorAndExit -exception $exception -roles "Attribute Definition Administrator"
    }
    Write-Host "Created new custom Security Attribute with ID: $($result.id)"
    Write-VerboseObject ($result | Select-Object -Property *)
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
    $result = $null
    $exception = $null
    if ($true -eq $whatIf) {
        Write-Warning "What-If mode is ON. Activating the CustomSecurityAttribute $($csa.name) {$($csa.id)}"
        Update-MgDirectoryCustomSecurityAttributeDefinition -CustomSecurityAttributeDefinitionId $csa.id -BodyParameter $params -WhatIf
        $result = $params
    } else {
        $exception = $($result = Update-MgDirectoryCustomSecurityAttributeDefinition -CustomSecurityAttributeDefinitionId $csa.id -BodyParameter $params) 2>&1
    }

    if ($null -ne $exception) {
        Write-CreationErrorAndExit -exception $exception -roles "CustomSecAttributeDefinition.ReadWrite.All"
    }
    Write-Host "Activated custom Security Attribute with ID: $($csa.id)"
    Write-VerboseObject ($result | Select-Object -Property *)
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
                $csaName = @("$csaValue")
            }
        }
    }
    Write-Debug "Parameters:"
    Write-DebugObject ($params | Select-Object -Property *)

    $exception = $null

    if ("ServicePrincipal" -eq $principalType) {
        if ($true -eq $whatIf){
            Write-Warning "What-If mode is ON. New ServicePrincipal is logged here"
            Update-MgServicePrincipal -ServicePrincipalId $principalId -BodyParameter $params -WhatIf
        } else {
            $exception = $($result = Update-MgServicePrincipal -ServicePrincipalId $principalId -BodyParameter $params) 2>&1
        }
    } elseif ("User" -eq $principalType) {
        if ($true -eq $whatIf){
            Write-Warning "What-If mode is ON. New User is logged here"
            Update-MgUser -UserId $principalId -BodyParameter $params -WhatIf
        } else {
            $exception = $($result = Update-MgUser -UserId $principalId -BodyParameter $params) 2>&1
        }
    }

    if ($null -ne $exception) {
        Write-CreationErrorAndExit -exception $exception -roles "Attribute Assignment Administrator"
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

    $exception = $null

    if ("ServicePrincipal" -eq $principalType) {
        if ($true -eq $whatIf){
            Write-Warning "What-If mode is ON. New ServicePrincipal is logged here"
            Update-MgServicePrincipal -ServicePrincipalId $principalId -BodyParameter $params -WhatIf
        } else {
            $exception = $($result = Update-MgServicePrincipal -ServicePrincipalId $principalId -BodyParameter $params) 2>&1
        }
    } elseif ("User" -eq $principalType) {
        if ($true -eq $whatIf){
            Write-Warning "What-If mode is ON. New User is logged here"
            Update-MgUser -UserId $principalId -BodyParameter $params -WhatIf
        } else {
            $exception = $($result = Update-MgUser -UserId $principalId -BodyParameter $params) 2>&1
        }
    }

    if ($null -ne $exception) {
        Write-CreationErrorAndExit -exception $exception -roles "Attribute Assignment Administrator"
    }
}
function Get-User {
    param (
        $UserId
    )
    try {
        Write-Debug "Getting User with ID: $UserId"
        $exception = $($user = Get-MgUser -UserId $UserId) 2>&1
        if ($null -ne $exception) {
            Write-Debug $exception
        }
        else {
            Write-Debug "User found: $user"
        }
        return $user
    }
    catch {
        Write-Warning "Error encountered while trying to get User with ID: $UserId"
        Write-Warning $_.Exception.Message
    }
    return $null
}

function Get-ServicePrincipal {
    param (
        $principalId
    )
    try {
        Write-Debug "Getting ServicePrincipal with ID: $principalId"
        $exception = $($servicePrincipal = Get-MgServicePrincipal -ServicePrincipalId $principalId) 2>&1
        if ($null -ne $exception) {
            Write-Debug $exception
        }
        else {
            Write-Debug "ServicePrincipal found: $($servicePrincipal | ConvertTo-Json -Depth 99)"
        }
        return $servicePrincipal
    }
    catch {
        Write-Warning "Error encountered while trying to get ServicePrincipal with ID: $principalId"
        Write-Warning $_.Exception.Message
    }
    return $null
}
# SIG # Begin signature block
# MIIFxQYJKoZIhvcNAQcCoIIFtjCCBbICAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCA/i9drvDRm51x6
# 1pEkRq8hNENqlLFtAtPHTuro/73xGKCCAzowggM2MIICHqADAgECAhBuQViVGZw2
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
# gjcCARUwLwYJKoZIhvcNAQkEMSIEIPbCb2td7f+1pRMnBMWhQisVOjN+zGk5DfvI
# Y2lDJxGMMA0GCSqGSIb3DQEBAQUABIIBAD6IZm1LT/UluvkGBuzFMseJ1A8hh4FY
# PbnuxFoEhsoRRyU+OY5NnoAAfrirsKVsZFueV6+0M+SFzkPQjqItLw8ncLf/eDCG
# WlwwKGUaMdYsK08X61ASh9KuQhGz5FIcxtz6EPdqMtTxKCQd8ymlBgK8ZDtufFuU
# 8FSEz8pvfpWPm+Gx8j5oEaORSeQTGkcOTUdGGtoxyZ43RlYGg2yvGIN5ICUse/lX
# AxQvH9xPOmJOXpA3cRcoCQ8SslNe93apmp1q2gWZS8rUFSXu1QY5yLIsaVKvg3T+
# 5kIjuubaGMHYiAJJnfeTKDYusSOY7D6+4eiQx8lCalCWL7ZEDfivBE8=
# SIG # End signature block
