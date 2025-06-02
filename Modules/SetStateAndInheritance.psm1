[CmdletBinding()]
param()

Import-Module $PSScriptRoot\AppManagementPolicies.psm1 -Force

function Set-DebugSetStateAndInheritance {
    param (
        $DebugPref
    )

    $script:DebugPreference = $DebugPref

    # Set Debug pref on all imported modules
    Set-DebugAppManagementPolicies($DebugPreference)
}

function Set-RestrictionState {
    param (
        $PolicyType,
        $RestrictionTypeName,
        $PolicyRestrictionType,
        $State
    )
    
    if ($null -eq $PolicyRestrictionType) {
        Write-Debug "No '$RestrictionTypeName' restriction defined on '$PolicyType' policy."
        return
    }

    #  State cannot be null, convert to enabled if being set to null
    if ($null -eq $State) {
        $State = "enabled"
    }

    Write-Debug "'$RestrictionTypeName' restriction is set on '$PolicyType' policy."

    $PreviousState = $PolicyRestrictionType.state

    # If state not set on policy restriction, set to new state
    if ($null -eq $PreviousState) {
        $PolicyRestrictionType | Add-Member -Force -NotePropertyName state -NotePropertyValue $State

        Write-Debug "Changed '$RestrictionTypeName' restriction state from '$PreviousState' to '$State' on '$PolicyType' policy."
        return
    }

    Write-Debug "Retaining '$RestrictionTypeName' restriction state '$PreviousState' on '$PolicyType' policy."
}

function Invoke-CheckRestrictionType {
    param (
        $PolicyType,
        $RestrictionTypeName,
        $PolicyRestrictionType,
        $TenantPolicyRestrictionType = $null
    )

    if ($null -eq $TenantPolicyRestrictionType) {
        if ($null -eq $PolicyRestrictionType) {
            return
        }

        # Clone the restriction type 
        $PolicyRestrictionTypeUpdated = $PolicyRestrictionType | Select-Object -Property *

        # If state not set on App Policy restriction, set to enabled
        Set-RestrictionState $PolicyType $RestrictionTypeName $PolicyRestrictionTypeUpdated
        return $PolicyRestrictionTypeUpdated
    }

    if ($null -eq $PolicyRestrictionType) {
        #  If App Policy doesn't have restriction type, shallow clone from Tenant Policy
        #  and set state to disabled
        Write-Debug "'$RestrictionTypeName' restriction missing on '$PolicyType' policy. Cloning it from 'Tenant' policy with 'disabled' state"

        # clone restriction type from Tenant policy and clear out state
        $PolicyRestrictionTypeUpdated = $TenantPolicyRestrictionType | Select-Object -ExcludeProperty state

        # set state as disabled on cloned custom policy restriction type
        Set-RestrictionState $PolicyType $RestrictionTypeName $PolicyRestrictionTypeUpdated "disabled"
        return $PolicyRestrictionTypeUpdated
    }

    # Clone the restriction type 
    $PolicyRestrictionTypeUpdated = $PolicyRestrictionType | Select-Object -Property *

    # If state not set on App Policy restriction, set to enabled
    Set-RestrictionState $PolicyType $RestrictionTypeName $PolicyRestrictionTypeUpdated
    return $PolicyRestrictionTypeUpdated
}

function Invoke-CheckRestrictions {
    param (
        $PolicyType,
        $RestrictionName,
        $PolicyRestrictions,
        $RestrictionType,
        $TenantPolicyRestrictions = $null
    )

    $RestrictionNames = Get-RestrictionNames -PolicyType $PolicyType -RestrictionType $RestrictionType

    $IsArray = $RestrictionNames.$RestrictionName -is [Array]

    if ($true -eq $IsArray) {
        $PolicyRestrictionsUpdated = [System.Collections.ArrayList]::new()
    } else {
        $PolicyRestrictionsUpdated = @{}
    }

    if ($null -eq $TenantPolicyRestrictions) {
        if ($null -eq $PolicyRestrictions) {
            Write-Debug "No '$RestrictionName' restrictions defined on '$PolicyType' policy."
            return
        }

        Write-Debug "Checking '$RestrictionName' restrictions on '$PolicyType' policy."
        if ($true -eq $IsArray){
            foreach ($RestrictionTypeName in $RestrictionNames.$RestrictionName) {
                $PolicyRestrictionType = $PolicyRestrictions | Where-Object { $_.restrictionType -eq $RestrictionTypeName }
                $RestrictionTypeUpdated = Invoke-CheckRestrictionType $PolicyType $RestrictionTypeName $PolicyRestrictionType
    
                # If RestrictionType is not null add it to the list
                if ($null -ne $RestrictionTypeUpdated) {
                    [void]$PolicyRestrictionsUpdated.Add($RestrictionTypeUpdated)
                }
            }
        } else {
            foreach ($RestrictionTypeName in $RestrictionNames.$RestrictionName.Keys) {
                
                $PolicyRestrictionType = $PolicyRestrictions.$RestrictionTypeName
                $RestrictionTypeUpdated = Invoke-CheckRestrictionType $PolicyType $RestrictionTypeName $PolicyRestrictionType
    
                # If RestrictionType is not null add it
                if ($null -ne $RestrictionTypeUpdated) {
                    $PolicyRestrictionsUpdated.$RestrictionTypeName = $RestrictionTypeUpdated
                }
            }
        }

        Write-Debug ("Returning " + $PolicyRestrictionsUpdated.Count + "'$RestrictionName' restrictions for '$PolicyType' policy.")
        Write-DebugObject @($PolicyRestrictionsUpdated)

        return $PolicyRestrictionsUpdated
    }

    # If App Policy doesn't have the restrictions, clone from Tenant Policy (excluding state)
    if ($null -eq $PolicyRestrictions) {
        if ($true -eq $IsArray) {
            $PolicyRestrictions = [System.Collections.ArrayList]::new()
        } else {
            $PolicyRestrictions = @{}
        }
    }

    Write-Debug "Checking '$RestrictionName' restrictions on '$PolicyType' policy."

    # Create empty list of updated restrictions
    if ($true -eq $IsArray){
        foreach ($RestrictionTypeName in $RestrictionNames.$RestrictionName) {
            $PolicyRestrictionType = $PolicyRestrictions | Where-Object { $_.restrictionType -eq $RestrictionTypeName }
            $TenantPolicyRestrictionType = $TenantPolicyRestrictions | Where-Object { $_.restrictionType -eq $RestrictionTypeName }
            
            $RestrictionTypeUpdated = Invoke-CheckRestrictionType $PolicyType $RestrictionTypeName $PolicyRestrictionType $TenantPolicyRestrictionType 
    
            # If RestrictionType is not null add it to the list
            if ($null -ne $RestrictionTypeUpdated) {
                [void]$PolicyRestrictionsUpdated.Add($RestrictionTypeUpdated)
            }
        }
    } else {
        foreach ($RestrictionTypeName in $RestrictionNames.$RestrictionName.Keys) {
            
            $PolicyRestrictionType = $PolicyRestrictions.$RestrictionTypeName
            $TenantPolicyRestrictionType = $TenantPolicyRestrictions.$RestrictionTypeName
            $RestrictionTypeUpdated = Invoke-CheckRestrictionType $PolicyType $RestrictionTypeName $PolicyRestrictionType $TenantPolicyRestrictionType

            # If RestrictionType is not null add it
            if ($null -ne $RestrictionTypeUpdated) {
                $PolicyRestrictionsUpdated.$RestrictionTypeName = $RestrictionTypeUpdated
            }
        }
    }


    Write-Debug ("Returning " + $PolicyRestrictionsUpdated.Count + "'$RestrictionName' restrictions for '$PolicyType' policy.")
    Write-DebugObject @($PolicyRestrictionsUpdated)

    return $PolicyRestrictionsUpdated
}

function Invoke-CheckAppRestrictions {
    param (
        $PolicyType,
        $AppRestrictionsName,
        $PolicyAppRestrictions,
        $TenantPolicyAppRestrictions = $null
    )

    $RestrictionNames = Get-RestrictionNames -PolicyType $PolicyType -RestrictionType $AppRestrictionsName

    $PolicyAppRestrictionsUpdated = @{}
    
    if ($null -eq $TenantPolicyAppRestrictions) {
        if ($null -eq $PolicyAppRestrictions) {
            Write-Debug "No '$AppRestrictionsName' app restrictions defined on '$PolicyType' policy."
            return
        }

        Write-Debug "Checking '$AppRestrictionsName' app restrictions on '$PolicyType' policy."
        foreach ($RestrictionName in $RestrictionNames.Keys) {
            $PolicyRestrictionsUpdated = Invoke-CheckRestrictions -PolicyType $PolicyType -RestrictionName $RestrictionName -PolicyRestrictions $PolicyAppRestrictions.$RestrictionName -RestrictionType $AppRestrictionsName
            $IsArray = $RestrictionNames.$RestrictionName -is [Array]

            if ($true -eq $IsArray) {
                if ($null -eq $PolicyRestrictionsUpdated) {
                    $PolicyRestrictionsUpdated = @()
                }
                $PolicyAppRestrictionsUpdated.$RestrictionName = @($PolicyRestrictionsUpdated)
            } else {
                if ($null -eq $PolicyRestrictionsUpdated) {
                    $PolicyRestrictionsUpdated = @{}
                }
                $PolicyAppRestrictionsUpdated.$RestrictionName = $PolicyRestrictionsUpdated
            }
        }

        Write-Debug "Returning '$AppRestrictionsName' app restriction for '$PolicyType' policy."
        Write-DebugObject $PolicyAppRestrictionsUpdated

        return $PolicyAppRestrictionsUpdated
    }

    # If App Policy doesn't have the app restrictions, copy over from Tenant Policy
    if ($null -eq $PolicyAppRestrictions) {
        Write-Debug "No '$AppRestrictionsName' app restrictions defined on '$PolicyType' policy."

        $PolicyAppRestrictions = @{}
    }

    Write-Debug "Checking '$AppRestrictionsName' app restrictions on '$PolicyType' policy."

    foreach ($RestrictionName in $RestrictionNames.Keys) {
        $tenantRestriction = Get-MatchingTenantPolicyRestriction -RestrictionType $AppRestrictionsName -RestrictionName $RestrictionName -TenantPolicyRestrictions $TenantPolicyAppRestrictions

        if ("applicationRestrictions" -eq $RestrictionName) {
            $PolicyRestrictionsUpdated = @{}
            foreach ($childRestrictionName in $RestrictionNames.$RestrictionName.Keys){
                $childRestriction = Invoke-CheckRestrictions -PolicyType $PolicyType -RestrictionName $childRestrictionName -PolicyRestrictions $PolicyAppRestrictions.$RestrictionName.$childRestrictionName -TenantPolicyRestrictions $tenantRestriction.$childRestrictionName -RestrictionType $childRestrictionName
                $PolicyRestrictionsUpdated.Add($childRestrictionName, $childRestriction)
            }
        } else {
            $PolicyRestrictionsUpdated = Invoke-CheckRestrictions -PolicyType $PolicyType -RestrictionName $RestrictionName -PolicyRestrictions $PolicyAppRestrictions.$RestrictionName -TenantPolicyRestrictions $tenantRestriction -RestrictionType $AppRestrictionsName
        }

        $IsArray = $RestrictionNames.$RestrictionName -is [Array]

        if ($true -eq $IsArray) {
            if ($null -eq $PolicyRestrictionsUpdated) {
                $PolicyRestrictionsUpdated = @()
            }
            $PolicyAppRestrictionsUpdated.$RestrictionName = @($PolicyRestrictionsUpdated)
        } else {
            if ($null -eq $PolicyRestrictionsUpdated) {
                $PolicyRestrictionsUpdated = @{}
            }
            $PolicyAppRestrictionsUpdated.$RestrictionName = $PolicyRestrictionsUpdated
        }
    }

    Write-Debug "Returning '$AppRestrictionsName' app restriction for '$PolicyType' policy."
    Write-DebugObject $PolicyAppRestrictionsUpdated

    return $PolicyAppRestrictionsUpdated
}

function Invoke-CheckApplicationManagementPolicy {
    param (
        $PolicyType,
        $Policy,
        $TenantPolicy = $null
    )

    # Clone the policy object
    $PolicyUpdated = $Policy | Select-Object -Property *

    Write-Debug ("Checking '$PolicyType' Policy: '" + $Policy.displayName + " (" + $Policy.id + ")'")

    if ($null -eq $TenantPolicy) {
        $PolicyUpdated.applicationRestrictions = Invoke-CheckAppRestrictions $PolicyType "applicationRestrictions" $Policy.applicationRestrictions
        $PolicyUpdated.servicePrincipalRestrictions = Invoke-CheckAppRestrictions $PolicyType "servicePrincipalRestrictions" $Policy.servicePrincipalRestrictions

        return $PolicyUpdated
    }

    $PolicyUpdated.restrictions = Invoke-CheckAppRestrictions $PolicyType "applicationRestrictions" $Policy.restrictions $TenantPolicy.applicationRestrictions

    return $PolicyUpdated
}

function Invoke-CheckApplicationManagementPolicies {
    param (
        $Tenant_Policy,
        $App_Policies,
        $WhatIf = $true
    )

    Write-Host ("'Tenant' policy: '" + $Tenant_Policy.displayName + "' (" + $Tenant_Policy.id + ")")
    Write-DebugObject $Tenant_Policy

    $TenantPolicyUpdated = Invoke-CheckApplicationManagementPolicy "Tenant" $Tenant_Policy

    Update-ApplicationManagementPolicy "Tenant" $TenantPolicyUpdated $WhatIf

    foreach ($Policy in $App_Policies) {
        Write-Host ("'Custom' policy: '" + $Policy.displayName + "' (" + $Policy.id + ")")
        Write-DebugObject $Policy
    
        $CustomPolicyUpdated = Invoke-CheckApplicationManagementPolicy "Custom" $Policy $Tenant_Policy

        Update-ApplicationManagementPolicy "Custom" $CustomPolicyUpdated $WhatIf
    }
}

function Get-MatchingTenantPolicyRestriction {
    param (
        $RestrictionType,
        $RestrictionName,
        $TenantPolicyRestrictions
    )

    $RestrictionNames = Get-RestrictionNames -PolicyType "Tenant" -RestrictionType $RestrictionType
    if ($RestrictionNames.Keys -contains $RestrictionName) {
        return $TenantPolicyRestrictions.$RestrictionName
    }

    # The schema for the Tenant Policy is different for the following restrictions. These need to be mapped correctly.
    if ($RestrictionName -eq "applicationRestrictions" -and $RestrictionType -eq "applicationRestrictions") {
        return [pscustomobject] @{
            identifierUris = $TenantPolicyRestrictions.identifierUris
            audiences = $TenantPolicyRestrictions.audiences
        }
    }
}
# SIG # Begin signature block
# MIIFxQYJKoZIhvcNAQcCoIIFtjCCBbICAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCAhSrN6/zHIKiXF
# H8ecqYR8WJtQkSnuyqfMP8zGyjr3g6CCAzowggM2MIICHqADAgECAhBuQViVGZw2
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
# gjcCARUwLwYJKoZIhvcNAQkEMSIEIM5INXTj4TQVuINZ3dU8UYthjqMhX2jRsMIv
# y1y02GHtMA0GCSqGSIb3DQEBAQUABIIBAJyYjYtdOVAPUZhEgQZnSmGxyQwQCzEw
# ucNZfuy+bVgqCK01NBZFV4CQFKXgvNX9pL5K4F4A8jOnO5EYORXkSaQHrGg6yEQJ
# e2n7THHqY1vY34RCURrh5Jwu/HYALdARxeW7zwIC1PsqD5xjk4Db2b6uAiKfyOAz
# WP6dFmzV2yShOjEXJj/xt/ZAsFzL9zGzlA63TgRdNihyc4CQqdDX4g4HU1dd1e1L
# 6SceMcM/cI1p8Xer4bY0B/GBDYsYub9Ufwh+KaVAeDWHjle5IYsKC7U/ohSzA7jG
# ESQlp/BuFJknwXOhYdgwBX24vdbs3JI/9oxwjT7UXEUNuyyK2Y9+fOU=
# SIG # End signature block
