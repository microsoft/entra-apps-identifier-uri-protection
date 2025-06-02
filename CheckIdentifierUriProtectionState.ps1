#Requires -Version 7.2.0
<#
.SYNOPSIS
    Powershell script to check the current status of the NonDefaultUriAddition restriction on the Tenant Default Application Management Policy.
.DESCRIPTION
    This PowerShell script will check the current state of the NonDefaultUriAddition restriction on the Tenant Default Application Management Policy and recommend
    the next steps to take.  The NonDefaultUriAddition restriction is a security feature that restricts the ability of applications to use non-default URIs.
.PARAMETER Environment
    Environment to connect to as listed in
    Get-MgEnvironment (https://learn.microsoft.com/en-us/powershell/module/microsoft.graph.authentication/get-mgenvironment?view=graph-powershell-1.0).
    If none specified, will use the Global (public) environment.
    Default: Global
.PARAMETER TenantId
    TenantId to connect to. If none specified, will present a common login page for all tenants.
    Default: common
.PARAMETER Login
    If the script should attempt to login to MS Graph first. You may also login separately using 
    Connect-MgGraph (https://learn.microsoft.com/en-us/powershell/module/microsoft.graph.authentication/connect-mggraph?view=graph-powershell-1.0).
    Default: True
.PARAMETER Logout
    If the script should logout from MS Graph at the end. You may also logout separately using 
    Disconnect-MgGraph (https://learn.microsoft.com/en-us/powershell/module/microsoft.graph.authentication/disconnect-mggraph?view=graph-powershell-1.0).
    Default: True
.EXAMPLE
    CheckIdentifierUriProtectionState.ps1
    To run the script and return the current state of the NonDefaultUriAddition restriction on the Tenant Default Application Management Policy.
.NOTES
    Author: Zachary Allison
    Date:   04 Dec 2024  
#>
[CmdletBinding()]
param(
    [Parameter(
        HelpMessage="Environment to connect to as listed in
        [Get-MgEnvironment](https://learn.microsoft.com/en-us/powershell/module/microsoft.graph.authentication/get-mgenvironment?view=graph-powershell-1.0).
        If none specified, will use the Global (public) environment.
        Default: Global"
    )]
    [string]$Environment = "Global",
    [Parameter(
        HelpMessage="TenantId to connect to. If none specified, will present a common login page for all tenants.
        Default: common"
    )]
    [string]$TenantId = "common",
    [Parameter(
        HelpMessage="If the script should attempt to login to MS Graph first. You may also login separately using 
        [Connect-MgGraph](https://learn.microsoft.com/en-us/powershell/module/microsoft.graph.authentication/connect-mggraph?view=graph-powershell-1.0).
        Default: True"
    )]
    [bool]$Login = $true,
    [Parameter(
        HelpMessage="If the script should logout from MS Graph at the end. You may also logout separately using 
        [Disconnect-MgGraph](https://learn.microsoft.com/en-us/powershell/module/microsoft.graph.authentication/disconnect-mggraph?view=graph-powershell-1.0).
        Default: True"
    )]
    [bool]$Logout = $true
)

Write-Host "Script starting. Confirming environment setup..."

Import-Module $PSScriptRoot\Modules\AppManagementPolicies.psm1 -Force
Set-DebugAppManagementPolicies($DebugPreference)

Write-Debug "Checking if Microsoft.Graph module is installed..."
Assert-ModuleExists -ModuleName "Microsoft.Graph" -InstallLink "https://learn.microsoft.com/en-us/powershell/microsoftgraph/installation?view=graph-powershell-1.0"

# Set the Environment for the connections.
Set-ExecutionEnvironment -Environment $Environment

if ($true -eq $Login) {
    # Login to MS Graph interactively
    # Use Global Admin creds at prompt
    Start-Login -TenantId $TenantId
}

# Get Tenant Application Management Policy
$Tenant_Policy = Get-TenantApplicationManagementPolicy
Write-Verbose $Tenant_Policy

$isStateSetByMicrosoft = $Tenant_Policy.applicationRestrictions.identifierUris.nonDefaultUriAddition.isStateSetByMicrosoft
$IsEnabled = $Tenant_Policy.applicationRestrictions.identifierUris.nonDefaultUriAddition.state

if ($null -eq $Tenant_Policy.applicationRestrictions.identifierUris.nonDefaultUriAddition) {
    Write-Message -Color "Yellow" -Message "IdentifierUri protection is disabled. It may be enabled by Microsoft in the future. Enable yourself by running ./EnableIdentifierUriProtection.ps1, or opt-out from any future enablement by running ./DisableIdentifierUriProtection.ps1."
}
elseif ("disabled" -eq $IsEnabled) {
    Write-Message -Color "Red" -Message "IdentifierUri protection is disabled and will not be enabled by Microsoft. Enable yourself by running ./EnableIdentifierUriProtection.ps1"
} else {
    if ($true -eq $isStateSetByMicrosoft) {
        Write-Message -Message "IdentifierUri protection is enabled. This was done by Microsoft. You can disable by running ./DisableIdentifierUriProtection (Not recommended)."
    } else {
        Write-Message -Message "IdentifierUri protection is enabled."
    }
}

if ($true -eq $Logout) {
    Start-Logout
}
# SIG # Begin signature block
# MIIFxQYJKoZIhvcNAQcCoIIFtjCCBbICAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCCg0AjBP+XO/G0N
# o2XOMAq1FRs0nb3tmtSpgE/NzS9KmqCCAzowggM2MIICHqADAgECAhBuQViVGZw2
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
# gjcCARUwLwYJKoZIhvcNAQkEMSIEIJ6jIhtgtmBLrv2R+iOew7xoT1MK+r6ZNQEO
# OjSRhb0SMA0GCSqGSIb3DQEBAQUABIIBADRYA8KYzQctIjc4yoBPigwhgglL28Uf
# Rt4H+6hXkmsw98++8OhpbavRjVYbB2N30G9nVKFGJvI6KzCpBIuXaCV06RfQk5QC
# 4tpOiJLgEJUbCXVQ2xGQ7diKe9TsXNGEpeC6EU3xttBkP2bRdR/z/fxfJyJQZVhP
# fe7YNZzz8bBwq+oq5drNjAuPUdKLZ8FjBDz312dugPmUFy1pSstYx7fPoRvmHQSj
# JHo+TDCzqGKd/ftiSeIE17mZ0ueZU6cIxLe5MZKYfBXHAUBguJILb4BKrh2YkcbC
# wjmiKY6N3K3gQPgK9WbnmhyHSDSVssuIT5sLu45xi/AddHSDUXwMYac=
# SIG # End signature block
