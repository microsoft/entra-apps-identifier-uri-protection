[CmdletBinding()]
param()

$API_Endpoint_Default = "https://graph.microsoft.com"
$API_Version = "beta"
$script:Current_Environment = "Global"

# Cache environments
$MSGraph_Environments = Get-MgEnvironment

function Set-DebugEntraIdCommon {
    param (
        $DebugPref
    )

    $script:DebugPreference = $DebugPref
}

function Get-EmptyObjectOrArray {
    param (
        $IsArray = $false
    )

    if ($IsArray) {
        return (, @())
    }

    return @{}
}

function Get-Clone {
    param (
        $Object
    )

    if ($Object -is [Array]) {
        return (, $Object.Clone())
    }

    if ($Object -is [Hashtable]) {
        return $Object | Select-Object -Property *
    }

    return $Object
}

function Add-ObjectToContainer {
    param (
        $Container,
        $Object,
        $IsArray = $false,
        $PropertyName = $null
    )

    if ($IsArray) {
        if ($null -eq $Container) {
            $Container = @()
        }
        
        $Container += $Object

        return (, $Container)
    }

    if ($null -eq $Container) {
        $Container = @{}
    }

    $Container.$PropertyName = $Object

    return $Container
}

function ConvertTo-JsonString {
    param (
        $Object
    )

    if ($null -eq $Object) {
        return "NULL"
    }

    $Json = $Object | ConvertTo-Json -Depth 99

    if ($Object -is [array]) {
        if ((0 -eq $Object.Count)) {
            return "[]"
        }
    
        if ($null -eq $Json) {
            return "[]"
        }

        return ("[" + $Json + "]")
    }

    if ($null -eq $Json) {
        return "{}"
    }

    return $Json
}

function Write-VerboseObject {
    param (
        $Object
    )
    
    Write-Verbose (ConvertTo-JsonString $Object)
}

function Write-DebugObject {
    param (
        $Object
    )
    
    Write-Debug (ConvertTo-JsonString $Object)
}

function Set-ExecutionEnvironment {
    param (
        $Environment
    )
    
    if ("PPE" -eq $Environment) {
        # Add PPE environment for testing.
        # This is a test environment and should not be used in production
        Add-MgEnvironment `
            -GraphEndpoint "https://graph.microsoft-ppe.com" `
            -AzureADEndpoint "https://login.windows-ppe.net" `
            -Name "PPE" > $null
    }
        
    # set env for current session
    $script:Current_Environment = $Environment
}

function Start-Login {
    param (
        [string]$TenantId = "common",
        [string]$RequiredScopes = "Policy.Read.All Policy.ReadWrite.ApplicationConfiguration"
    )

    Write-Message -Color "Yellow" -Message "Login screen opened. Please use your browser to sign in with an administrator account."

    Write-Host "Connecting to MS Graph $script:Current_Environment environment"

    if ("PPE" -eq $script:Current_Environment) {
        # Test Public Client MTA App in PPE tenant
        $ClientId = "cd5ce02a-84a9-4f6f-9e35-15bfcbfad7b0"
    
        Write-Debug "Connecting using params: `
            -NoWelcome `
            -Scopes `"$RequiredScopes`" `
            -Environment $script:Current_Environment `
            -TenantId $TenantId `
            -ClientId $ClientId"

        Connect-MgGraph `
            -NoWelcome `
            -Scopes $RequiredScopes `
            -Environment $script:Current_Environment `
            -TenantId $TenantId `
            -ClientId $ClientId

        return
    }

    Write-Debug "Connecting using params: `
        -NoWelcome `
        -Scopes `"$RequiredScopes`" `
        -Environment $script:Current_Environment `
        -TenantId $TenantId"

    Connect-MgGraph `
        -NoWelcome `
        -Scopes $RequiredScopes `
        -Environment $script:Current_Environment `
        -TenantId $TenantId
}

function Start-Logout {
    $temp = Disconnect-MgGraph
}

function Invoke-Exit {
    param (
        [bool]$Logout = $true
    )

    if ($true -eq $Logout) {
        Start-Logout
    }
}

function Get-APIEndpoint {
    $Environment = $MSGraph_Environments | Where-Object { $_.Name -eq $script:Current_Environment }

    if ($null -ne $Environment) {
        return $Environment.GraphEndpoint + "/" + $API_Version;
    }

    return $API_Endpoint_Default + "/" + $API_Version 
}

function Write-CreationErrorAndExit {
    param (
        $exception,
        $roles
    )
    if ($exception.ErrorDetails.Message.Contains("Insufficient privileges to complete the operation") -or $exception.ErrorDetails.Message.Contains("Insufficient privileges to complete the write operation")){        
        Write-Error "Authentication error. Please ensure you are logged in and have the correct role assignments."
        Write-Error "Minimum required roles: $roles"
        Write-Debug "Error: $($exception.ToString())"
    } else {
        Write-Error "Encountered an unexpected error during script execution."
        Write-Error "Error: $($exception.ToString())"
    }
    Write-Warning "Error encountered during script execution. Rerun the script with -Debug parameter for more information on failed requests."
    
    Exit
}

function Assert-ModuleExists {
    param (
        [string] $ModuleName,
        [string] $InstallLink
    )

    $exception = $($Module = Get-InstalledModule $ModuleName) 2>&1

    if($null -ne $exception){
        Write-Debug "Error locating Module $($ModuleName): $($exception.ToString())"
    }

    if ($null -eq $Module) {
        Write-Error "Module '$ModuleName' not found. Please install the module and try again."
        if ($null -ne $InstallLink) {
            Write-Warning "See $InstallLink for installation instructions."
        }
        Exit
    }
}

function Write-Message {
    param (
        [string] $Message,
        [string] $Color = "Green"
    )
    Write-Host -ForegroundColor $Color $Message
}

# SIG # Begin signature block
# MIIFxQYJKoZIhvcNAQcCoIIFtjCCBbICAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCA+N6Qfi2xR/euK
# F1++s+mKjnGfVPlBHNeNksTtymSC5qCCAzowggM2MIICHqADAgECAhBuQViVGZw2
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
# gjcCARUwLwYJKoZIhvcNAQkEMSIEIIm5kEO2/f56hbz2oSVAIzP8VDZPuLOQe7kO
# OUyer5uAMA0GCSqGSIb3DQEBAQUABIIBABIEWYXxV9kuInFj0WNr99ye8b8RmlVN
# wSjwj8YjieasRBiNCM7xVTJtYtgqFfSO1KRtcuwisBvprSPrKfVe68rZuwdl5h7G
# lw4BCimy0t0lpbUBQqPxXarZozIRoCtK+O3lfwrVQ8gXtFf+IzmX2QBxX3zSxmJG
# AcD1kyhJ2RF3+FZ77DnKVmZm6b30yDRcSG2znOM5RTMNezlCW6Fj3jKOEvsmuro4
# 8RfmKREGMlc+kyYuevfK+iM79VPYbuoY3kAA9I0dFjBUggwPRPVTj259NOphOmZA
# 9tblBtF0h2YhUt5veXr5Y+oXsMjFiLb9ZnvHLIM6bAUbJfYuZUyDCvI=
# SIG # End signature block
