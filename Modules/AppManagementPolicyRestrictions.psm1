[CmdletBinding()]
param()

Import-Module $PSScriptRoot\AppManagementPolicies.psm1 -Force

function Set-DebugAppManagementPolicyRestrictions {
    param (
        $DebugPref
    )

    $script:DebugPreference = $DebugPref

    # Set Debug pref on all imported modules
    Set-DebugAppManagementPolicies($DebugPreference)
}


function New-RestrictionType {
    param (
        [ValidateSet("enabled", "disabled")]
        $State,
        $RestrictionTypeName = $null,
        $RestrictForAppsCreatedAfterDateTime = $null,
        $OtherProps = $null
    )

    $RestrictionType = @{
        state = $State
    }

    if ([string] $RestrictForAppsCreatedAfterDateTime -as [DateTime]) {
       $RestrictionType.Add("restrictForAppsCreatedAfterDateTime", $RestrictForAppsCreatedAfterDateTime)
    } else {
        Write-Debug "RestrictForAppsCreatedAfterDateTime $RestrictForAppsCreatedAfterDateTime is not a valid DateTime value. Removing from RestrictionType."
    }

    if ($null -ne $RestrictionTypeName) {
        $RestrictionType.restrictionType = $RestrictionTypeName
    }

    if ($null -ne $OtherProps) {
        foreach ($Key in $OtherProps.Keys) {
            $RestrictionType.$Key = $OtherProps.$Key
        }
    }

    return $RestrictionType
}
<#
.SYNOPSIS Create an empty CustomPolicy object for the specified AppId.
#>
function New-CustomPolicyForAppId {
    param (
        $AppId,
        $DisplayName
    )
    return @{
        displayName = $displayName
        description = "When this policy is applied to an app, it provides an exemption to the restriction blocking the addition of non-default identifier URIs"
        isEnabled = $true
        restrictions = @{
            passwordCredentials = @(
            )
            keyCredentials = @(
            )
        }
    }
}

function Set-RestrictionState {
    param (
        $PolicyType,
        $RestrictionTypeName,
        $RestrictionType,
        $State = "enabled"
    )

    if ($null -eq $RestrictionType) {
        throw ("Cannot set state. RestrictionType '" + $RestrictionTypeName + "' is null.")
    }

    $PreviousState = $RestrictionType.state

    # If state not set on policy restriction, set to new state
    $RestrictionType | Add-Member -Force -NotePropertyName state -NotePropertyValue $State

    Write-Debug "Changed '$RestrictionTypeName' restriction state from '$PreviousState' to '$State' on '$PolicyType' policy."

    return $RestrictionType
}

function Set-RestrictionType {
    param (
        $PolicyType,
        $RestrictionTypeNameToSet,
        $RestrictionTypeExisting,
        $RestrictionTypeToSet
    )

    if ($null -eq $RestrictionTypeExisting) {
        Write-Verbose ("Restriction type '" + $RestrictionTypeNameToSet + "' doesn't exists on '" + $PolicyType + "' policy. Setting the provided restriction type.")
        Write-VerboseObject $RestrictionTypeToSet

        return $RestrictionTypeToSet
    }

    if ($null -eq $RestrictionTypeToSet) {
        throw ("Cannot set null restriction type '" + $RestrictionTypeNameToSet + "' on '" + $PolicyType + "' policy.")
    }

    Write-Debug ("Updating existing Restriction State for '" + $RestrictionTypeNameToSet + "' on '" + $PolicyType + "' policy.")

    $RestrictionTypeExisting = Set-RestrictionState $PolicyType $RestrictionTypeNameToSet $RestrictionTypeExisting $RestrictionTypeToSet.state

    return $RestrictionTypeExisting
}

function Get-RestrictionType {
    param (
        $Restrictions,
        $RestrictionTypeName
    )
    
    # If array get the element matching restrictionType property
    if ($Restrictions -is [array]) {
        return $Restrictions | Where-Object { $_.restrictionType -eq $RestrictionTypeName }
    }

    # If hashtable, get property by name
    return $Restrictions.$RestrictionTypeName
}

function Assert-ContainsRestrictionTypeName {
    param (
        $RestrictionNames,
        $RestrictionTypeName
    )

    # If array check if value exists
    if ($RestrictionNames -is [array]) {
        return $RestrictionNames.Contains($RestrictionTypeName)
    }

    # If hashtable, check if key exists
    return $RestrictionNames.ContainsKey($RestrictionTypeName)
}

function Set-Restrictions {
    param (
        $PolicyType,
        $RestrictionNameToSet,
        $RestrictionTypeNames,
        $RestrictionsExisting,
        $RestrictionsToSet
    )

    # Password and Key Credentials are array while all the new restrictions
    # like identifierUris are objects/hastables, hence the different processing
    $IsArray = $RestrictionTypeNames -is [array]

    if ($null -eq $RestrictionsExisting) {
        Write-Verbose "No '$RestrictionNameToSet' restrictions defined on '$PolicyType' policy. Will create a new one."
        
        $RestrictionsExisting = Get-EmptyObjectOrArray $IsArray
    }

    Write-Debug "Checking '$RestrictionNameToSet' restrictions on '$PolicyType' policy."
    Write-DebugObject $RestrictionsExisting

    # We are only supposting a hastable based restriction type in the nested restriction object to set
    $RestrictionTypeNameToSet = Write-Output $RestrictionsToSet.Keys[0]

    if ($false -eq (Assert-ContainsRestrictionTypeName $RestrictionTypeNames $RestrictionTypeNameToSet)) {
        throw ("Trying to set invalid restriction type '" + $RestrictionTypeNameToSet + "' on '" + $PolicyType + "' policy.")
    }

    # New Restriction Type
    $RestrictionTypeToSet = $RestrictionsToSet.$RestrictionTypeNameToSet

    # Create empty restrictions array/object
    $RestrictionsNew = Get-EmptyObjectOrArray $IsArray

    if ($IsArray) {
        $RestrictionTypeNamesArray = $RestrictionTypeNames
    } else {
        $RestrictionTypeNamesArray = $RestrictionTypeNames.Keys
    }

    # We loop through all restriction types in this restriction and update the one
    #  that matches 
    foreach ($Name in $RestrictionTypeNamesArray) {
        $RestrictionTypeExisting = Get-RestrictionType $RestrictionsExisting $Name

        # only update the specified restriction type
        if ($Name -eq $RestrictionTypeNameToSet) {
            $RestrictionTypeExisting = Set-RestrictionType $PolicyType $RestrictionTypeNameToSet $RestrictionTypeExisting $RestrictionTypeToSet
        }
        
        # If RestrictionType is not null add it to the array/object
        if ($null -ne $RestrictionTypeExisting) {
            $RestrictionsNew = Add-ObjectToContainer $RestrictionsNew $RestrictionTypeExisting $IsArray $Name
        }
    }

    Write-Debug ("Updated '$RestrictionNameToSet' restrictions for '$PolicyType' policy.")
    Write-DebugObject $RestrictionsNew

    if ($IsArray) {
        return (, $RestrictionsNew)
    }

    return $RestrictionsNew
}

function Set-Restriction_AppRestrictions {
    param (
        $PolicyType,
        $AppRestrictionsNameToSet,
        $RestrictionsNames,
        $AppRestrictionsExisting,
        $AppRestrictionsToSet
    )

    if ($null -eq $AppRestrictionsExisting) {
        Write-Debug "No '$AppRestrictionsNameToSet' app restrictions defined on '$PolicyType' policy. Will create a new app restrictions"

        $AppRestrictionsExisting = @{}
    }

    Write-Debug "Checking '$AppRestrictionsNameToSet' app restrictions on '$PolicyType' policy."
    Write-DebugObject $AppRestrictionsExisting

    # currently supports only one restriction to set
    $RestrictionNameToSet = Write-Output $AppRestrictionsToSet.Keys[0]

    if ($false -eq $RestrictionsNames.ContainsKey($RestrictionNameToSet)) {
        throw ("Trying to set invalid restrictions of type '" + $RestrictionNameToSet + "' on '" + $PolicyType + "' policy.")
    }

    # Restriction Types Names for the current Restriction Name to set
    $RestrictionTypeNames = $RestrictionsNames.$RestrictionNameToSet

    # Existing Restrictions
    $RestrictionsExisting = $AppRestrictionsExisting.$RestrictionNameToSet
    # New Restrictions
    $RestrictionsToSet = $AppRestrictionsToSet.$RestrictionNameToSet

    $AppRestrictionsExisting.$RestrictionNameToSet = Set-Restrictions $PolicyType $RestrictionNameToSet $RestrictionTypeNames $RestrictionsExisting $RestrictionsToSet

    Write-Debug "Returning '$AppRestrictionsNameToSet' app restriction for '$PolicyType' policy."
    Write-DebugObject $AppRestrictionsExisting

    return $AppRestrictionsExisting
}

function Set-Restriction_ApplicationManagementPolicy {
    param (
        $PolicyType,
        $Policy,
        $PolicyRestrictionNestedObjectToSet
    )

    Write-Host ("'" + $PolicyType + "' policy: '" + $Policy.displayName + "' (" + $Policy.id + ")")
    Write-DebugObject $Policy

    if ("Tenant" -eq $PolicyType) {
        $AppRestrictionsNames = Get-TenantPolicyRestrictionsNames
    }

    if ("Custom" -eq $PolicyType) {
        $AppRestrictionsNames = Get-CustomPolicyRestrictionsNames
    }

    if ($null -eq $AppRestrictionsNames) {
        throw ("No app restrictions defined for '" + $PolicyType + "' policy type.")
    }

    # Current supports setting only a single apprestriction + restriction + restrictiontype
    # combination in the nested structure
    $AppRestrictionsNameToSet = Write-Output $PolicyRestrictionNestedObjectToSet.Keys[0]

    if ($false -eq $AppRestrictionsNames.ContainsKey($AppRestrictionsNameToSet)) {
        throw ("Trying to set invalid app restrictions of type '" + $AppRestrictionsNameToSet + "' on '" + $PolicyType + "' policy.")
    }

    # Restriction Names for this App Restrictions to set
    $RestrictionsNames = $AppRestrictionsNames.$AppRestrictionsNameToSet

    # Existing App Restrictions
    if ($PolicyType -eq "Custom") {
        $AppRestrictionsExisting = $Policy.restrictions.$AppRestrictionsNameToSet
    } else {
        $AppRestrictionsExisting = $Policy.$AppRestrictionsNameToSet
    }

    # New App Restrictions
    $AppRestrictionsToSet = $PolicyRestrictionNestedObjectToSet.$AppRestrictionsNameToSet

    if ($PolicyType -eq "Custom") {
        $Policy.restrictions.$AppRestrictionsNameToSet = Set-Restriction_AppRestrictions $PolicyType $AppRestrictionsNameToSet $RestrictionsNames $AppRestrictionsExisting $AppRestrictionsToSet
    } else {
        $Policy.$AppRestrictionsNameToSet = Set-Restriction_AppRestrictions $PolicyType $AppRestrictionsNameToSet $RestrictionsNames $AppRestrictionsExisting $AppRestrictionsToSet
    }
    return $Policy
}

function Set-ApplicationManagementPolicyRestriction {
    param (
        $PolicyType,
        $Policy,
        $RestrictionTypeName,
        $PolicyRestrictionNestedObjectToSet,
        $WhatIf = $true
    )

    if ($null -eq $RestrictionTypeName) {
        throw "Cannot set null restriction on '$PolicyType' Policy"
    }

    Write-Host ("Setting restriction '$RestrictionTypeName' on '$PolicyType' policy")

    $Policy = Set-Restriction_ApplicationManagementPolicy $PolicyType $Policy $PolicyRestrictionNestedObjectToSet
    return $Policy
}

function Set-ApplicationManagementPolicyRestriction_IdentifierUris {
    param (
        $PolicyType,
        $Policy,
        $RestrictionTypeName = "uriAdditionWithoutUniqueTenantIdentifier",
        $RestrictForAppsCreatedAfterDateTime = $null,
        $State = "enabled",
        $WhatIf = $true
    )

    $RestrictionTypeObject = New-RestrictionType `
        -State $State `
        -RestrictForAppsCreatedAfterDateTime $RestrictForAppsCreatedAfterDateTime `
        -OtherProps @{
            "excludeAppsReceivingV2Tokens" = $true
            "excludeSaml" = $true
        }

    $PolicyRestrictionNestedObjectToSet = @{
        "applicationRestrictions" = @{
            "identifierUris" = @{
                $RestrictionTypeName = $RestrictionTypeObject
            }
        }
    }

    $Policy = Set-ApplicationManagementPolicyRestriction `
        -PolicyType $PolicyType `
        -Policy $Policy `
        -RestrictionTypeName $RestrictionTypeName `
        -PolicyRestrictionNestedObjectToSet $PolicyRestrictionNestedObjectToSet `
        -WhatIf $WhatIf
        
    return $Policy
}

# SIG # Begin signature block
# MIIFxQYJKoZIhvcNAQcCoIIFtjCCBbICAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCBtxLhTVdFBitJ0
# 68Ejm1QnFTrjkn4CWI0Qf8sH61RdYKCCAzowggM2MIICHqADAgECAhBuQViVGZw2
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
# gjcCARUwLwYJKoZIhvcNAQkEMSIEIDAi7weeJKkJSiSLz/RCinPL3kTcLn+8IQZ/
# WLKgVm0jMA0GCSqGSIb3DQEBAQUABIIBAG6AAIR21JBfsVYt+yZdUp7zk8w0BSYe
# aaSvcHMe3MZt+kDtAzpVb6+AC+csI4P9ADcxqpRThY5IeW4NpADB24zBp+ZVF6i5
# ZDRWqckucGL/2XhZTsSs0VKJjCEZ9pnGUB4aM/XPX7QbOC5o0elVyayCOJZBzYnJ
# QXypZPDn5Uvl1bt7BpOkrTHkndSKV1IjrQSZgnXKoHUiaYZ/jS0yHhM2fbYxCS4T
# 2BDcThoVX0A23xPvoBZAXNQMrB/x8M8EhhggGotN8K6k0wRYJxfzU3B3ld4eJrv0
# stw96yMezrAaDVpNNHj/JaeEN/Rm7izNT2ucSDzvY0VRlBulT1oh8Ws=
# SIG # End signature block
