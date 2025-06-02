[CmdletBinding()]
param()

Import-Module $PSScriptRoot\EntraIdCommon.psm1 -Force

function Set-DebugApplication {
    param (
        $DebugPref
    )

    $script:DebugPreference = $DebugPref

    # Set Debug pref on all imported modules
    Set-DebugEntraIdCommon($DebugPreference)
}


function Get-AppByAppId {
    param(
        [string]$AppId
    )
    $exception = $($App = Get-MgApplicationByAppId -AppId $AppId) 2>&1
    if ($null -eq $App) {
        Write-Debug "Encountered an error while getting Application with AppId $AppId."
        Write-Debug "Exception: $($exception.ToString())"
        throw "Failed to get Application with AppId $AppId."
    }
    return $App
}
# SIG # Begin signature block
# MIIFxQYJKoZIhvcNAQcCoIIFtjCCBbICAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCCgjzHGJJWBIyGL
# Sri8/RUNMdf9LtPhCtNv4pnbZvm+OKCCAzowggM2MIICHqADAgECAhBuQViVGZw2
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
# gjcCARUwLwYJKoZIhvcNAQkEMSIEICMUZ/w/qRY8yWaLHVuEaR8g7Yu2jblOJOa4
# eoH/4mieMA0GCSqGSIb3DQEBAQUABIIBAI86X2ophYXLMgE6E4WJLOmMP97mPjht
# BNQeRVR7eod9Eoni43q14aL8e4UkXFmuzfVsuNkl8LgHoAJP5oI18B/kJqtmTCoB
# Xgd2xLeBfwGejCkuULeOWXUYc+euNZAVWjwg6pondY02FVDmmaXVyhdOVtECl/PG
# BB182hnY95xDSOGpw+uyWyuNrgLlO7jnbLvHo/eDdvKAKKoLvlCw7E/5O9gYbbl2
# G6Eer45R4FzB1iCBlHG9CMTzhyWoZ7vrBPHuibn7dHWNE7hOojH2Z6ls3o34QKcp
# zMA8XL5Aluem+Nf2btceUMT271HRo2hvp4LTCBfwUhvePpcf89XqKNc=
# SIG # End signature block
