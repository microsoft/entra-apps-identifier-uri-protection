# Module: SetPolicyOnApp.psm1
# Description: This module provides functions to manage and assign policies to applications.

[CmdletBinding()]
param()

Import-Module $PSScriptRoot\AppManagementPolicies.psm1 -Force
Import-Module $PSScriptRoot\AppManagementPoliciesAssignment.psm1 -Force
Import-Module $PSScriptRoot\AppManagementPolicyRestrictions.psm1 -Force

<#
.SYNOPSIS
Sets the debug preference for the SetPolicyOnApp module.

.DESCRIPTION
This function sets the debug preference for the current module and propagates the preference to all imported modules.

.PARAMETER DebugPref
The debug preference to set (e.g., 'Continue', 'SilentlyContinue').

.EXAMPLE
Set-DebugSetPolicyOnApp -DebugPref 'Continue'
#>
function Set-DebugSetPolicyOnApp {
    param (
        [Parameter(Mandatory = $true)]
        [string]$DebugPref
    )

    $script:DebugPreference = $DebugPref

    # Set Debug preference on all imported modules
    Set-DebugAppManagementPolicies($DebugPreference)
    Set-DebugAppManagementPolicyRestrictions($DebugPreference)
    Set-DebugAppManagementPolicyAssignment($DebugPreference)
}

<#
.SYNOPSIS
Retrieves the app management policy assigned to a specific application.

.DESCRIPTION
This function retrieves the app management policy assigned to a given application by its AppId. If no policy is assigned, it returns null.

.PARAMETER AppId
The ID of the application for which the policy is to be retrieved.

.EXAMPLE
Get-AppManagementPolicyForApp -AppId '12345'
#>
function Get-AppManagementPolicyForApp {
    param(
        [Parameter(Mandatory = $true)]
        [string]$AppId
    )

    try {
        Write-Debug "Attempting to retrieve the policy for application ID: $AppId."

        $assignedPolicy = Get-MgApplicationAppManagementPolicy -ApplicationId $AppId

        if ($null -eq $assignedPolicy) {
            Write-Verbose "No policy is currently assigned to the application with ID: $AppId."
            return $null
        }

        Write-Debug "Policy retrieved: $($assignedPolicy | ConvertTo-Json -Depth 99)"

        $policyId = $assignedPolicy.Id

        if (-not $policyId) {
            Write-Verbose "No policy ID found for the application with ID: $AppId."
            return $null
        }

        $AppPolicy = Get-CustomApplicationManagementPolicy -Id $policyId
        return $AppPolicy

    } catch {
        Write-Error "Error retrieving the app management policy for AppId: $AppId. Details: $_"
        return $null
    }
}

<#
.SYNOPSIS
Retrieves an existing custom policy by its display name.

.DESCRIPTION
This function searches for a custom policy by its display name among all existing policies.

.PARAMETER PolicyName
The display name of the policy to retrieve.

.EXAMPLE
Get-ExistingNonDefaultUriCustomPolicy -PolicyName 'MyCustomPolicy'
#>
function Get-ExistingNonDefaultUriCustomPolicy {
    param(
        [Parameter(Mandatory = $true)]
        [string]$PolicyName
    )

    try {
        Write-Debug "Searching for a policy with the name: $PolicyName."

        $existingPolicies = Get-CustomApplicationManagementPolicies
        foreach ($policy in $existingPolicies) {
            if ($PolicyName -eq $policy.displayName) {
                return $policy
            }
        }

        Write-Verbose "No policy found with the name: $PolicyName."
        return $null
    } catch {
        Write-Error "Error retrieving the policy with name: $PolicyName. Details: $_"
        throw
    }
}

<#
.SYNOPSIS
Creates a new policy with a specified restriction disabled.

.DESCRIPTION
This function creates a new app management policy with a specified restriction set to 'disabled'.

.PARAMETER Policy
The base policy object to modify.

.PARAMETER RestrictionTypeName
The name of the restriction to disable (e.g., 'nonDefaultUriAddition').

.PARAMETER WhatIf
Indicates whether to simulate the operation without making actual changes.

.EXAMPLE
Invoke-CreateNewPolicyWithDisabledRestriction -Policy $policy -RestrictionTypeName 'nonDefaultUriAddition' -WhatIf $true
#>
function Invoke-CreateNewPolicyWithDisabledRestriction {

    param (
        [Parameter(Mandatory = $true)]
        [object]$Policy,

        [Parameter(Mandatory = $true)]
        [ValidateSet("nonDefaultUriAddition", "uriAdditionWithoutUniqueTenantIdentifier")]
        [string]$RestrictionTypeName,

        [Parameter(Mandatory = $false)]
        [bool]$WhatIf = $false
    )

    try {
        Write-Debug "Disabling restriction: $RestrictionTypeName."

        $Policy = Set-ApplicationManagementPolicyRestriction_IdentifierUris `
            -PolicyType "Custom" `
            -Policy $Policy `
            -RestrictionTypeName $RestrictionTypeName `
            -State "disabled" `
            -WhatIf $WhatIf

        Write-Debug "Creating the new policy with the specified restriction disabled."
        $newPolicy = New-CustomApplicationManagementPolicy -Policy $Policy -WhatIf $WhatIf

        return $newPolicy
    } catch {
        Write-Error "Error creating the new policy with restriction: $RestrictionTypeName. Details: $_"
        throw
    }
}

<#
.SYNOPSIS
Assigns a policy to an application, replacing any existing policy if necessary.

.DESCRIPTION
This function assigns a specified policy to an application. If an existing policy is assigned, it will be removed before assigning the new policy.

.PARAMETER AppId
The ID of the application to which the policy will be assigned.

.PARAMETER Policy
The policy object to assign to the application.

.PARAMETER OldPolicyId
The ID of the existing policy to remove from the application.

.PARAMETER WhatIf
Indicates whether to simulate the operation without making actual changes.

.EXAMPLE
Invoke-AssignPolicyToApp -AppId '12345' -Policy $policy -OldPolicyId '67890' -WhatIf $true
#>
# Assign a policy to an application
function Invoke-AssignPolicyToApp {
    param(
        [Parameter(Mandatory = $true)]
        [string]$AppId,

        [Parameter(Mandatory = $true)]
        [object]$Policy,

        [Parameter(Mandatory = $false)]
        [string]$OldPolicyId,

        [Parameter(Mandatory = $false)]
        [bool]$WhatIf = $true
    )

    try {
        if ($OldPolicyId) {
            Write-Warning "Existing policy ($OldPolicyId) found attached to the application. Removing it before assigning the new policy."
            Remove-AppManagementPolicyAssignment -AppId $AppId -PolicyId $OldPolicyId -WhatIf $WhatIf
        }

        Write-Debug "Assigning the new policy to the application."
        
        New-AppManagementPolicyAssignment -AppId $AppId -Policy $Policy -WhatIf $WhatIf
    } catch {
        Write-Error "Error assigning the policy to the application. Details: $_"
        throw
    }
}
# SIG # Begin signature block
# MIIFxQYJKoZIhvcNAQcCoIIFtjCCBbICAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCAaCxwNbAfRmADb
# 3PEGUCoMw4fzcIinxXWwbcNBnimNa6CCAzowggM2MIICHqADAgECAhBuQViVGZw2
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
# gjcCARUwLwYJKoZIhvcNAQkEMSIEIKGNdt03dyRtoEfxc2S2HhJ/TLhHlb01zcA+
# 3q3BGTJKMA0GCSqGSIb3DQEBAQUABIIBAA6ODxr1BO1JNSfi5k6j/reCTq8jgqUL
# PnyeY0a8ks7IPrUYXNysBhmhQWltH8tGDiB1ukCxjy2kVV0HHvccmrcspiCo7ig/
# ZbCErhJCNngWPf6VwvIAcMnhWnDFsh/hw7EZMFmHqikZ1G3IbV8eamiWs0fZLs4W
# rZHFUXSeJS2UA3W3XcvEVQOCtcBfOzf5t1UqbW7FrVqqyaIc4GUVSv+LszlYTz6y
# XNA0sc8dCB0LCgBPME3sm0jD6R1GJGD8DBPJiRtIhd5q3dpBiljSBQB2FP8rwzfY
# OBOUoPeSza7VqTzud4M6rqiK+BaHE71i309Jcmysa554QKI4WjdNb/Q=
# SIG # End signature block
