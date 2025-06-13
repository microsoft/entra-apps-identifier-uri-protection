# Module: AppManagementPoliciesAssignment.psm1
# Description: This module provides functions to manage app management policy assignments.

[CmdletBinding()]
param()

Import-Module $PSScriptRoot\EntraIdCommon.psm1 -Force
Import-Module $PSScriptRoot\AppManagementPolicies.psm1 -Force

<#
.SYNOPSIS
Sets the debug preference for the App Management Policy Assignment module.

.DESCRIPTION
This function sets the debug preference for the current module and propagates the preference to all imported modules.

.PARAMETER DebugPref
The debug preference to set (e.g., 'Continue', 'SilentlyContinue').

.EXAMPLE
Set-DebugAppManagementPolicyAssignment -DebugPref 'Continue'
#>
function Set-DebugAppManagementPolicyAssignment {
    param (
        [Parameter(Mandatory = $true)]
        [string]$DebugPref
    )

    $script:DebugPreference = $DebugPref

    # Set Debug preference on all imported modules
    Set-DebugEntraIdCommon($DebugPreference)
}

<#
.SYNOPSIS
Constructs the reference URL for a custom app management policy.

.DESCRIPTION
This function generates the reference URL for a given policy ID by combining the API endpoint with predefined URI segments.

.PARAMETER PolicyId
The ID of the policy for which the reference URL is to be constructed.

.EXAMPLE
Get-CustomAppManagementPolicyReference -PolicyId '12345'
#>
function Get-CustomAppManagementPolicyReference {
    param(
        [Parameter(Mandatory = $true)]
        [string]$PolicyId
    )

    return (Get-PoliciesUrl) + "/" + $PolicyId
}

<#
.SYNOPSIS
Assigns a new app management policy to an application.

.DESCRIPTION
This function assigns a specified app management policy to an application. It supports a WhatIf mode for testing.

.PARAMETER AppId
The ID of the application to which the policy will be assigned.

.PARAMETER Policy
The policy object to assign to the application.

.PARAMETER WhatIf
Indicates whether to simulate the operation without making actual changes.

.EXAMPLE
New-AppManagementPolicyAssignment -Policy $policy -AppId '12345' -WhatIf $true
#>
function New-AppManagementPolicyAssignment {
    param(
        [Parameter(Mandatory = $true)]
        [string]$AppId,

        [Parameter(Mandatory = $true)]
        [object]$Policy,

        [Parameter(Mandatory = $false)]
        [bool]$WhatIf = $true
    )

    try {
        $oDataReference = Get-CustomAppManagementPolicyReference -PolicyId $Policy.id
        $params = @{ "@odata.id" = $oDataReference }

        Write-Debug "Preparing to assign the policy to the application."
        Write-DebugObject $params

        if ($WhatIf) {
            New-MgApplicationAppManagementPolicyByRef -ApplicationId $AppId -BodyParameter $params -ErrorAction Stop -WhatIf
        } else {
            New-MgApplicationAppManagementPolicyByRef -ApplicationId $AppId -BodyParameter $params -ErrorAction Stop
        }

        Write-Host "Policy ($($Policy.id)) successfully assigned to application ($AppId)."
    } catch {
        Write-Error "Error assigning the policy to the application. Details: $_"
        throw
    }
}

<#
.SYNOPSIS
Removes an existing app management policy assignment from an application.

.DESCRIPTION
This function removes a specified app management policy assignment from an application. It supports a WhatIf mode for testing.

.PARAMETER AppId
The ID of the application from which the policy will be removed.

.PARAMETER PolicyId
The ID of the policy to remove from the application.

.PARAMETER WhatIf
Indicates whether to simulate the operation without making actual changes.

.EXAMPLE
Remove-AppManagementPolicyAssignment -AppId '12345' -PolicyId '67890' -WhatIf $true
#>
function Remove-AppManagementPolicyAssignment {
    param(
        [Parameter(Mandatory = $true)]
        [string]$AppId,

        [Parameter(Mandatory = $true)]
        [string]$PolicyId,

        [Parameter(Mandatory = $false)]
        [bool]$WhatIf = $true
    )

    try {
        Write-Host "Initiating removal of policy ($PolicyId) from application ($AppId)."

        if ($WhatIf) {
            Remove-MgApplicationAppManagementPolicyByRef -ApplicationId $AppId -AppManagementPolicyId $PolicyId -ErrorAction Stop -WhatIf
        } else {
            Remove-MgApplicationAppManagementPolicyByRef -ApplicationId $AppId -AppManagementPolicyId $PolicyId -ErrorAction Stop
        }

        Write-Host "Policy ($PolicyId) successfully removed from application ($AppId)."
    } catch {
        Write-Error "Error removing the policy from the application. Details: $_"
        throw
    }
}
# SIG # Begin signature block
# MIIFxQYJKoZIhvcNAQcCoIIFtjCCBbICAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCCzIS/yptcjGz2q
# /+Prpiz2EalGFmpfvqpuUJfkeG6HXKCCAzowggM2MIICHqADAgECAhBuQViVGZw2
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
# gjcCARUwLwYJKoZIhvcNAQkEMSIEICa3xWvRQiWTjdawvd+kNVdkHi4U1kxtF6DZ
# NI5mrdClMA0GCSqGSIb3DQEBAQUABIIBAEQpcCaec7/uIw22HJIbsQqYqNviwsG6
# V+k5awdAW+RD3mNxAran484C0/qNSGKgoWePocL43TMrq1uHMSZpwcG2t+QX5A0G
# F3HfxY0aIxrMX1c+tUS1kCcq7RTR3Jqfa1YGFP8CY48nPgHHnaYKDhDEkh68dHOS
# YQqv9tSd3G5+3b/ujgNrzySoRIpV4sGvLi9pJOitjS96J0TwpciOMXDc3ogcT+1S
# wJ/cC963V4QDlbL2+fs7kwpZw5PeINjkxEBKUFan+yirgk/IST5uWybVMm4xdgVO
# fMR4pgceqv0sIdrkqz2ekIYWeCTDiE2HjUwPmmxOqpsJ2Oprk9fS7pY=
# SIG # End signature block
