[CmdletBinding()]
param()

Import-Module $PSScriptRoot\EntraIdCommon.psm1 -Force

$API_URI_Policies = "/policies"
$API_URI_Tenant_Policy = "/defaultAppManagementPolicy"
$API_URI_App_Policies = "/appManagementPolicies"

$ApplicationRestrictionsCommon = @{
    "passwordCredentials" = @(
        "passwordAddition"
        "passwordLifetime"
        "symmetricKeyAddition"
        "symmetricKeyLifetime"
        "customPasswordAddition"
    )
    "keyCredentials" = @(
        "asymmetricKeyLifetime"
    )
}

$IdentifierUris = @{
    "uriAdditionWithoutUniqueTenantIdentifier" = @{}
    "nonDefaultUriAddition" = @{}
}

$Audiences = @{
    "azureAdMultipleOrgs" = @{}
    "personalMicrosoftAccount" = @{}
}

$AppRestrictionsApplication = $ApplicationRestrictionsCommon + @{
    "identifierUris" = $IdentifierUris
    "audiences" = $Audiences
}

$AppRestrictionsServicePrincipal = $ApplicationRestrictionsCommon + @{
    # current nothing
}

$TenantPolicyRestrictions = @{
    "applicationRestrictions" = $AppRestrictionsApplication
    "servicePrincipalRestrictions" = $AppRestrictionsServicePrincipal
}

# This represents the "restrictions" property on the custom policy object.
$CustomPolicyRestrictions = $ApplicationRestrictionsCommon + @{
    "applicationRestrictions" = @{
        "identifierUris" = $IdentifierUris
        "audiences" = $Audiences
    }
}

function Get-PoliciesUrl {
    return (Get-APIEndpoint) + $API_URI_Policies + $API_URI_App_Policies
}

function Get-RestrictionNames {
    param (
        $PolicyType,
        $RestrictionType
    )
    if ("Custom" -eq $PolicyType) {
        # The mappings for applicationRestrictions are handled differently for custom policies.
        if ("identifierUris" -eq $RestrictionType -or "audiences" -eq $RestrictionType) {
            return $CustomPolicyRestrictions.applicationRestrictions
        }
        return $CustomPolicyRestrictions
    }

    if ("Tenant" -eq $PolicyType) {
        if ("applicationRestrictions" -eq $RestrictionType) {
            return $AppRestrictionsApplication
        } elseif ("servicePrincipalRestrictions" -eq $RestrictionType) {
            return $AppRestrictionsServicePrincipal
        } else {
            throw "Invalid restriction type: $RestrictionType"
        }
    }

    throw "Invalid policy type: $RestrictionType"
}

function Set-DebugAppManagementPolicies {
    param (
        $DebugPref
    )

    $script:DebugPreference = $DebugPref

    # Set Debug pref on all imported modules
    Set-DebugEntraIdCommon($DebugPreference)
}

function Get-TenantPolicyRestrictionsNames {
    return $TenantPolicyRestrictions
}

function Get-CustomPolicyRestrictionsNames {
    return $CustomPolicyRestrictions
}

<#
.SYNOPSIS
    Get the tenant application management policy from the Entra ID tenant.
#>
function Get-TenantApplicationManagementPolicy {
    $Tenant_Policy_URL = (Get-APIEndpoint) + $API_URI_Policies + $API_URI_Tenant_Policy

    Write-Debug "GET $Tenant_Policy_URL"

    Write-Progress "Getting tenant policy."
    $Tenant_Policy = Invoke-MGGraphRequest -Method GET -URI $Tenant_Policy_URL -OutputType PSObject

    if ($null -eq $Tenant_Policy) {
        throw "Failed to get Tenant policy."
    }

    return $Tenant_Policy
}

<#
.SYNOPSIS
    Get all custom application management policies from the Entra ID tenant.
#>
function Get-CustomApplicationManagementPolicies {
    $App_Policies_URL = (Get-APIEndpoint) + $API_URI_Policies + $API_URI_App_Policies

    Write-Debug "GET $App_Policies_URL"

    Write-Progress "Getting all Custom application management policies."
    $App_Policies_Response = Invoke-MGGraphRequest -Method GET -URI $App_Policies_URL -OutputType PSObject

    if (($null -eq $App_Policies_Response) -or ($null -eq $App_Policies_Response.Value)) {
        throw "Failed to list 'Custom' policies"
    }

    if (0 -eq $App_Policies_Response.Value.Count) {
        Write-Host "There are no 'Custom' policies in the tenant. Exiting."
        return @() # return empty array
    }

    return $App_Policies_Response.Value
}

<#
.SYNOPSIS 
    Get a custom application management policy from the Entra ID tenant with the specified id.
.PARAMETER Id
    The ID of the custom application management policy to retrieve.
#>
function Get-CustomApplicationManagementPolicy {
    param (
        $Id
    )

    $App_Policy_URL = (Get-APIEndpoint) + $API_URI_Policies + $API_URI_App_Policies + "/" + $Id

    Write-Debug "GET $App_Policy_URL"

    Write-Progress "Getting all Custom application management policies."
    $App_Policy = Invoke-MGGraphRequest -Method GET -URI $App_Policy_URL -OutputType PSObject

    if ($null -eq $App_Policy) {
        throw "Failed to get 'Custom' policiy with id $Id"
    }

    Write-Host "Found 'Custom' policy: $($App_Policy.displayName) ($($App_Policy.id))"
    Write-VerboseObject $App_Policy

    return $App_Policy
}

<#
.SYNOPSIS
    Update the application management policy in the Entra ID tenant and return the updated Policy.
.PARAMETER PolicyType
    The type of the policy to update (e.g., 'Tenant' or 'Custom').
.PARAMETER Policy
    The policy object to update.
.PARAMETER WhatIf
    A switch parameter to indicate if the operation should be a dry run (default is $true).
#>
function Update-ApplicationManagementPolicy {
    param (
        $PolicyType,
        $Policy,
        $WhatIf = $true
    )

    if ("Tenant" -eq $PolicyType) {
        $API_URI_Policy = $API_URI_Tenant_Policy
    } else {
        $API_URI_Policy = "$API_URI_App_Policies/" + $Policy.id
    }
    
    $Policy_URL = (Get-APIEndpoint) + $API_URI_Policies + $API_URI_Policy

    $srcubbedPolicy = Invoke-ScrubPolicyForPatch -Policy $Policy -PolicyType $PolicyType
    $Body = $srcubbedPolicy | ConvertTo-Json -Depth 99

    Write-Debug "PATCH $Policy_URL"
    Write-Debug "Body: $Body" 

    if ($false -eq $WhatIf) {
        Write-Progress "Updating '$PolicyType' policy."
        $exception = $($result = Invoke-MGGraphRequest -Method Patch -URI $Policy_URL -Body $Body) 2>&1

        if ($null -ne $exception) {
            Write-CreationErrorAndExit -exception $exception -roles "Security Administrator, Cloud Application Administrator"
        }

        if ("Tenant" -eq $PolicyType) {
            $PolicyUpdated = Get-TenantApplicationManagementPolicy
        } else {
            $PolicyUpdated = Get-CustomApplicationManagementPolicy $Policy.id
        }

        Write-Host ("Successfully updated the '$PolicyType' policy. '" + $Policy.displayName + " (" + $Policy.id + ")'")
        
    } else {
        Write-Warning "What-If mode is ON. updated policy is logged here"

        $PolicyUpdated = $srcubbedPolicy | Select-Object -Property *

        Write-Host ("Updated '$PolicyType' policy. '" + $Policy.displayName + " (" + $Policy.id + ")'")
    }

    Write-VerboseObject $PolicyUpdated
}

<#
.SYNOPSIS
    Create the custom application management policy in the Entra ID tenant and return the updated Policy.
.PARAMETER Policy
    The policy object to crate.
.PARAMETER WhatIf
    A switch parameter to indicate if the operation should be a dry run (default is $true).
#>
function New-CustomApplicationManagementPolicy {
    param (
        $Policy,
        $WhatIf = $true
    )

    $Policy_URL = (Get-APIEndpoint) + $API_URI_Policies + $API_URI_App_Policies

    $srcubbedPolicy = Invoke-ScrubPolicyForPatch -Policy $Policy -PolicyType "Custom"
    $Body = $srcubbedPolicy | ConvertTo-Json -Depth 99

    Write-Debug "POST: $Policy_URL"
    Write-Debug "Body: $Body" 

    if ($false -eq $WhatIf) {
        Write-Progress "Creating custom policy."
        $exception = $($newPolicy = Invoke-MGGraphRequest -Method POST -URI $Policy_URL -Body $Body) 2>&1

        if ($null -ne $exception) {
            Write-CreationErrorAndExit -exception $exception -roles "Cloud Application Administrator"
        }
        
        Write-Host ("Successfully created the custom policy. '" + $Policy.displayName + " (" + $newPolicy.id + ")'")
        
    } else {
        Write-Warning "What-If mode is ON. updated policy is logged here"

        $newPolicy = $srcubbedPolicy | Select-Object -Property *

        Write-Host ("Created custom policy. '" + $newPolicy.displayName + " (" + $newPolicy.id + ")'")
    }

    Write-VerboseObject $newPolicy
    return $newPolicy
}

<#
.SYNOPSIS
    Remove the properties that are not allowed in the PATCH request from the policy object.
.PARAMETER Policy
    The policy object to scrub.
#>
function Invoke-ScrubPolicyForPatch {
    param (
        $Policy,
        $PolicyType
    )

    # Existing ExcludeActors objects contain an odataContext type in the GET which is disallowed in the patch. Remove it.
    # Audiences is a new property that is only allowed for certain tenants. Remove it if it is not present.
    if("Tenant" -eq $PolicyType) {
        $Policy.applicationRestrictions.identifierUris.uriAdditionWithoutUniqueTenantIdentifier =
            Invoke-ScrubExcludeActors $Policy.applicationRestrictions.identifierUris.uriAdditionWithoutUniqueTenantIdentifier
        $Policy.applicationRestrictions.identifierUris.nonDefaultUriAddition =
            Invoke-ScrubExcludeActors $Policy.applicationRestrictions.identifierUris.nonDefaultUriAddition

        $Policy.applicationRestrictions = Invoke-ScrubKeyCredentials $Policy.applicationRestrictions
        $Policy.applicationRestrictions = Invoke-ScrubPasswordCredentials $Policy.applicationRestrictions

        $Policy.servicePrincipalRestrictions = Invoke-ScrubKeyCredentials $Policy.servicePrincipalRestrictions
        $Policy.servicePrincipalRestrictions = Invoke-ScrubPasswordCredentials $Policy.servicePrincipalRestrictions

        if ($null -eq $Policy.applicationRestrictions.audiences -or $Policy.applicationRestrictions.audiences.Count -eq 0) {
            $appRestrictions = $Policy.applicationRestrictions
            if ($appRestrictions -is [PSCustomObject]) {
                $appRestrictions.PSObject.Properties.Remove('audiences')
            } else {
                $appRestrictions.Remove('audiences')
            }

            $Policy.applicationRestrictions = $appRestrictions
        } else {
            $Policy.applicationRestrictions.audiences.azureAdMultipleOrgs =
                Invoke-ScrubExcludeActors $Policy.applicationRestrictions.audiences.azureAdMultipleOrgs
            $Policy.applicationRestrictions.audiences.personalMicrosoftAccount =
                Invoke-ScrubExcludeActors $Policy.applicationRestrictions.audiences.personalMicrosoftAccount
        }
    } else {
        $Policy.restrictions = Invoke-ScrubKeyCredentials $Policy.restrictions
        $Policy.restrictions = Invoke-ScrubPasswordCredentials $Policy.restrictions

        if ($null -ne $Policy.restrictions.applicationRestrictions){
            $Policy.restrictions.applicationRestrictions.identifierUris.uriAdditionWithoutUniqueTenantIdentifier =
                Invoke-ScrubExcludeActors $Policy.restrictions.applicationRestrictions.identifierUris.uriAdditionWithoutUniqueTenantIdentifier

            $Policy.restrictions.applicationRestrictions.identifierUris.nonDefaultUriAddition =
                Invoke-ScrubExcludeActors $Policy.restrictions.applicationRestrictions.identifierUris.nonDefaultUriAddition

            if ($null -eq $Policy.restrictions.applicationRestrictions.audiences){
                $appRestrictions = $Policy.restrictions.applicationRestrictions
                if ($appRestrictions -is [PSCustomObject]) {
                    $appRestrictions.PSObject.Properties.Remove('audiences')
                } else {
                    $appRestrictions.Remove('audiences')
                }
                $Policy.restrictions.applicationRestrictions = $appRestrictions
            } else {
                $Policy.restrictions.applicationRestrictions.audiences.azureAdMultipleOrgs =
                    Invoke-ScrubExcludeActors $Policy.restrictions.applicationRestrictions.audiences.azureAdMultipleOrgs
                $Policy.restrictions.applicationRestrictions.audiences.personalMicrosoftAccount =
                    Invoke-ScrubExcludeActors $Policy.restrictions.applicationRestrictions.audiences.personalMicrosoftAccount
            }
        }
    }

    return $Policy
}

function Invoke-ScrubExcludeActors {
    param (
        $ChildRestriction
    )
    if ($null -ne $ChildRestriction) {
        $excludeActors = $ChildRestriction.excludeActors
        if ($null -ne $excludeActors) {
            if ($excludeActors -is [PSCustomObject]) {
                $excludeActors.PSObject.Properties.Remove('customSecurityAttributes@odata.context')
            } else {
                $excludeActors.Remove('customSecurityAttributes@odata.context')
            }
            $ChildRestriction.excludeActors = $excludeActors
        }
    }

    return $ChildRestriction
}

function Invoke-ScrubKeyCredentials {
    param (
        $restriction
    )
    if ($null -ne $restriction) {
        if ($restriction -is [PSCustomObject]) {
            $restriction.PSObject.Properties.Remove('keyCredentials@odata.context')
        } else {
            $restriction.Remove('keyCredentials@odata.context')
        }
    }

    return $restriction
}

function Invoke-ScrubPasswordCredentials {
    param (
        $restriction
    )
    if ($null -ne $restriction) {
        if ($restriction -is [PSCustomObject]) {
            $restriction.PSObject.Properties.Remove('passwordCredentials@odata.context')
        } else {
            $restriction.Remove('passwordCredentials@odata.context')
        }
    }

    return $restriction
}
# SIG # Begin signature block
# MIIFxQYJKoZIhvcNAQcCoIIFtjCCBbICAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCDMvunELDiHrPz/
# yWZry4MIoY6t0C+gAG+vMk6EM+yYS6CCAzowggM2MIICHqADAgECAhBuQViVGZw2
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
# gjcCARUwLwYJKoZIhvcNAQkEMSIEIAOqHltEnDoZRtF8ygk/i4xz6snmWUv7Aw4L
# Ps0rzln8MA0GCSqGSIb3DQEBAQUABIIBAIYyQBBgGzDLWsSJpdTqsq7ygzKVNgZW
# 64auyhOFzfzQ3FS/5ZuGszRE8mDM9QgWsdR55oLxwfNOJjDRyGGsEfJq2gZLfvml
# 6lrGfzQKLBrrpXc6MY2lm6gccPAO0FdushA9a8c8H8yknUmslL37XmFHh+lFRliF
# 9GLfhkMXxkmU4O85hnmaHSsgRL3AmeTVvCH8z1Ylzmvw7fC4kxG5OOcRtnQnjFa7
# qjLDcLV8MJ6vFqMyCIo4trFjqUSkKhoIGW5opouxdj/MpV6pSoIPeMsdj4KnWcuB
# Ldxqd2cWQYMoJn4HpkXU3VE76q5TgEX+8GJ+LcHoq0v+woqDwGIDVJ8=
# SIG # End signature block
