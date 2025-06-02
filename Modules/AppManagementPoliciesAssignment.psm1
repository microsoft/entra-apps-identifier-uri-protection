[CmdletBinding()]
param()

Import-Module $PSScriptRoot\EntraIdCommon.psm1 -Force

function Set-DebugAppManagementPolicyAssignment {
    param (
        $DebugPref
    )

    $script:DebugPreference = $DebugPref

    # Set Debug pref on all imported modules
    Set-DebugEntraIdCommon($DebugPreference)
}

$API_URI_Policies = "/policies"
$API_URI_App_Policies = "/appManagementPolicies"
function Get-CustomAppManagementPolicyReference{
    param(
        [string]$PolicyId
    )
    $Policy_URL = (Get-APIEndpoint) + $API_URI_Policies + $API_URI_App_Policies
    return "$Policy_URL/$PolicyId"
}
    
function New-AppManagementPolicyAssignment {
    param(
        $Policy,
        $AppId,
        [bool] $WhatIf = $true
    )
    $oDataReference = Get-CustomAppManagementPolicyReference $Policy.id
    $params = @{
        "@odata.id" = $oDataReference
    }

    Write-Debug "Assigning the policy to the app."
    Write-DebugObject $params
    # Assign the policy to the app
    if ($WhatIf){
        New-MgApplicationAppManagementPolicyByRef -ApplicationId $AppId -BodyParameter $params -WhatIf
    } else {
        $exception = $($result = New-MgApplicationAppManagementPolicyByRef -ApplicationId $AppId -BodyParameter $params) 2>&1
        if ($null -ne $exception) {
            Write-CreationErrorAndExit -exception $exception -roles "Cloud Application Administrator"
        }
    }

    Write-Host "Successfully assigned the policy ($($Policy.id)) to the app ($AppId)."

    return $assignedPolicy
}

function Remove-AppManagementPolicyAssignment {
    param(
        $AppId,
        $PolicyId,
        [bool] $WhatIf = $true
    )
    Write-Host "Removing the existing policy ($PolicyId) from the app ($AppId)."
    if ($WhatIf){
        Remove-MgApplicationAppManagementPolicyByRef -ApplicationId $AppId -AppManagementPolicyId $PolicyId -WhatIf
    } else {
        $exception = $($result = Remove-MgApplicationAppManagementPolicyByRef -ApplicationId  $AppId -AppManagementPolicyId $PolicyId) 2>&1
        if ($null -ne $exception) {
            Write-CreationErrorAndExit -exception $exception -roles "Cloud Application Administrator"
        }
    }
    Write-Host "Successfully removed the existing policy ($PolicyId) from the app ($AppId)."
}
# SIG # Begin signature block
# MIIFxQYJKoZIhvcNAQcCoIIFtjCCBbICAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCA2eELqsMUuBstP
# TygzPMRhXBqiOa7x0ys7pbtmDEJw+qCCAzowggM2MIICHqADAgECAhBuQViVGZw2
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
# gjcCARUwLwYJKoZIhvcNAQkEMSIEICg1QVbT9dqdgqtPqPMZdvyXPqnguzay1oNC
# kvEa3W3qMA0GCSqGSIb3DQEBAQUABIIBACqqRoq8GDs71oO0thJf7LEhfsj2fLop
# 5vPMFZT6nJGNzQ5lmTj6MNpPiptofIhzn5exGXPw3bB+hVqeIX3lRnzB35ABk+q5
# x17DiVgxpmEQK3uQVpKQLjl3p7uRuOYLxgBtuhiPFGIN/0N53GV8z8PgXI+VpCU4
# KTmRurK0quCJYEdyuQ08YwJziNxh2iI99ZaiIqGoyohPYrNuKrrDb/qjhais21V4
# MXnpYVvJMlI4rfNQZk4Vk7KTYWQGfYQKgDVVd4KlrWheLT5hvUJMxeQH7gW6vrtP
# C7JKNqiN6H12ooPdHJaid3wX0Yv/ROIj1qi5SqXu0SFWiyzhQ7Qy/tA=
# SIG # End signature block
