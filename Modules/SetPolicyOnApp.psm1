[CmdletBinding()]
param()

Import-Module $PSScriptRoot\AppManagementPolicies.psm1 -Force
Import-Module $PSScriptRoot\AppManagementPoliciesAssignment.psm1 -Force
Import-Module $PSScriptRoot\AppManagementPolicyRestrictions.psm1 -Force

function Set-DebugSetPolicyOnApp {
    param (
        $DebugPref
    )

    $script:DebugPreference = $DebugPref

    # Set Debug pref on all imported modules
    Set-DebugAppManagementPolicies($DebugPreference)
    Set-DebugAppManagementPolicyRestrictions($DebugPreference)
    Set-DebugAppManagementPolicyAssignment($DebugPreference)
}

function Get-AppManagementPolicyForApp{
    param(
        [Parameter(Mandatory=$true)]
        [string]$AppId
    )

    # Get the assigned policy for the app. Calls the V1.0 endpoint.
    $exception = $($assignedPolicy = Get-MgApplicationAppManagementPolicy -ApplicationId $AppId) 2>&1
    if ($null -ne $exception) {
        Write-Error "Encountered an unexpected error during script execution."
        Write-Error "Error: $($exception.ToString())"
    }
    else {
        Write-Debug "Policy found: $($assignedPolicy | ConvertTo-Json -Depth 99)"
    }

    $policyId = $assignedPolicy.Id
    if(-not $policyId){
        Write-Debug "No policy assigned to the app."
        return 
    }
    # Get the policy from the beta endpoint to ensure it has the most up-to-date data.
    $AppPolicy = Get-CustomApplicationManagementPolicy -Id $policyId
    return $AppPolicy
}

function Get-ExistingNonDefaultUriCustomPolicy {
    param(
        $PolicyName
    )
    # Get all the policies, then filter on the display name.
    $existingPolicies = Get-CustomApplicationManagementPolicies
    foreach ($policy in $existingPolicies){
        if ($PolicyName -eq $policy.displayName){
            return $policy
        }
    }
    return $null
}

function Invoke-CreateNewPolicyWithNonDefaultUriAdditionDisabled{
    param(
        [Parameter(Mandatory=$true)]
        $Policy,
        [bool] $WhatIf = $true
    )
    if ($null -eq $Policy) {
        throw("Policy is null.")
    }

    Write-Debug "Disabling the policy for NonDefaultUriAddition."
    $newPolicy = Set-ApplicationManagementPolicyRestriction_NonDefaultUriAddition -PolicyType "Custom" -Policy $Policy  -State "disabled" -WhatIf $true
    Write-Debug "Creating the new policy."
    $newPolicy = New-CustomApplicationManagementPolicy -Policy $newPolicy -WhatIf $WhatIf
    return $newPolicy
}

function Invoke-AssignPolicyToApp{
    param(
        [string]$AppId,
        $Policy,
        [string] $OldPolicyId,
        [bool] $WhatIf = $true
    )

    if($OldPolicyId){
        # Remove the existing policy from the app
        Write-Warning "Existing policy found attached to the app. The current policy will be removed."
        Remove-AppManagementPolicyAssignment -AppId $AppId -PolicyId $OldPolicyId -WhatIf $WhatIf
    }

    Write-Debug "Assigning the new policy to the app."
    New-AppManagementPolicyAssignment -Policy $Policy -AppId $AppId -WhatIf $WhatIf
}
# SIG # Begin signature block
# MIIFxQYJKoZIhvcNAQcCoIIFtjCCBbICAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCAe+Lgqq7uZCXMT
# SukpKtgAeqnJ4pMO08mldCKil9jMqKCCAzowggM2MIICHqADAgECAhBuQViVGZw2
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
# gjcCARUwLwYJKoZIhvcNAQkEMSIEIEAOdAl2/Z4L8w0ymt/2RIACqVMHVCpGc5iI
# zTP+gzz/MA0GCSqGSIb3DQEBAQUABIIBACka6aSiv2zfSpdolW2YOUAJ5PNloNkA
# rNF1lXo72gORTCBKMfrNbs5glhFfn5ZV095bpQx3fDlA+PhzWxVLYSqxInugZ16+
# L//h4KlqOZ9B3Uv8LM3THpNZuMkUOrN2hCxYrJ6nPyEnq6zU5mVIv3/T6SmfY7p7
# aV8lxQDXi2L/R8QgG/3kKMxVj2eUCQDpf15zEf02zGyXY5moZJH0JMr2ba3HBOOe
# CVLEIyiB6YkBK1wLtqqxbfWmUqIrhxMPCvyFQxKwCG5RnpO5mR6lkwB3BWtt8i2V
# T6g2CaefQ60MEdQQNkPDBLSjWZvjzQTFs7PZMgGCbPpL+xB3Pi8Uubg=
# SIG # End signature block
