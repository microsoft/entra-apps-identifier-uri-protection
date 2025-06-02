[CmdletBinding()]
param()

Import-Module $PSScriptRoot\CustomSecurityAttributes.psm1 -Force

Import-Module $PSScriptRoot\AppManagementPolicies.psm1 -Force

function Invoke-GetPrincipalType {
    param (
        [string]
        $PrincipalId
    )

    if (-not $PrincipalId) {
        Write-Error "ID is required."
        Exit
    }

    Write-Debug "Checking if the supplied Principal ID is a user."
    $user = Get-User -UserId $PrincipalId
    if (-not $null -eq $user) {
        return "User"
    }

    Write-Debug "Checking if the supplied Principal ID is a ServicePrincipal."
    $servicePrincipal = Get-ServicePrincipal -principalId $PrincipalId
    if (-not $null -eq $servicePrincipal) {
        return "ServicePrincipal"
    }

    return $null
}

function Invoke-EnsureCustomSecurityAttributeObjects {
    param (
        [string]$attributeSetName,
        [string]$csaName,
        [string]$csaValue,
        [bool]$whatIf
    )
    if (-not $attributeSetName) {
        Write-Error "CustomSecurityAttributeSetName is required."
        Exit
    }

    if (-not $csaName) {
        Write-Error "CustomSecurityAttributeName is required."
        Exit
    }

    if (-not $csaValue) {
        Write-Error "CustomSecurityAttributeValue is required."
        Exit
    }
    
    Write-Debug "Getting the attribute set for the CSA"
    $attributeSet = Get-AttributeSet -attributeSetId $attributeSetName
    if ($null -eq $attributeSet) {
        Write-Debug "AttributeSet not found. Prompt user for confirmation and create."
        New-AttributeSet -attributeSetName $attributeSetName -whatIf $whatIf
    }
    else {
        Write-Debug "AttributeSet exists. Proceeding."
    }

    $csaId = $attributeSetName + "_" + $csaName
    $csa = Get-CustomSecurityAttribute -customSecurityAttributeId $csaId
    if ($null -eq $csa) {
        Write-Debug "CSA not found. Create."
        New-StringValueCustomSecurityAttribute -attributeSetName $attributeSetName `
                                               -csaName $csaName `
                                               -csaValue $csaValue `
                                               -whatIf $whatIf `
    }
    elseif ("Deprecated" -eq $csa.status) {
        Write-Message -Color "Yellow" -Message "CustomSecurityAttribute {$($csa.name)} is currently 'Deprecated'. Setting the status to 'Available'"
        Update-ActivateCustomSecurityAttribute -csa $csa -WhatIf $whatIf

    }
    else {
        Write-Debug "CustomSecurityAttribute exists. Proceeding."
    }

    $defaultTenantAppManagementPolicy = Get-TenantApplicationManagementPolicy
    $csaExemptionApplied = Invoke-CheckCSAExemptionsOnPolicy -Policy $defaultTenantAppManagementPolicy -CsaId $csaId

    if (-not $csaExemptionApplied){
        Write-Debug "CSAExemption not found on Default Tenant policy. Create."
        $oDataTypeName = "@odata.type"
        $newCsaExemption = @{
            $oDataTypeName = "#microsoft.graph.customSecurityAttributeStringValueExemption"
            id = $csaId
            operator = "equals"
            value = $csaValue
        }
        Invoke-AddCSAExemptionToNonDefaultUriAddition -Policy $defaultTenantAppManagementPolicy -CsaExemption $newCsaExemption -whatIf $whatIf
    }
}

function Invoke-CheckCSAExemptionsOnPolicy {
    param (
        $Policy,
        $CsaId
    )
    Write-Debug "Checking if CSAExemption $CsaId is already applied to the policy. Existing Exemptions:"
    Write-DebugObject $Policy.applicationRestrictions.identifierUris.nonDefaultUriAddition.excludeActors.customSecurityAttributes

    foreach($csaExemption in $Policy.applicationRestrictions.identifierUris.nonDefaultUriAddition.excludeActors.customSecurityAttributes){
        if ($csaExemption.id -eq $CsaId){
            return $true
        }
    }
    return $false
}

function Invoke-AddCSAExemptionToNonDefaultUriAddition {
    param (
        $Policy,
        $CsaExemption,
        [bool]$whatIf
    )

    if ($null -eq $Policy.applicationRestrictions){
        $Policy.applicationRestrictions = @{}
    }

    if ($null -eq $Policy.applicationRestrictions.identifierUris) {
        $Policy.applicationRestrictions.identifierUris = @{}
    }

    if ($null -eq $Policy.applicationRestrictions.identifierUris.nonDefaultUriAddition) {
        $Policy.applicationRestrictions.identifierUris.nonDefaultUriAddition = @{}
    }

    if ($null -eq $Policy.applicationRestrictions.identifierUris.nonDefaultUriAddition.excludeActors) {
        $Policy.applicationRestrictions.identifierUris.nonDefaultUriAddition.excludeActors = @{}
    }

    if ($null -eq $Policy.applicationRestrictions.identifierUris.nonDefaultUriAddition.excludeActors.customSecurityAttributes) {
        $Policy.applicationRestrictions.identifierUris.nonDefaultUriAddition.excludeActors.customSecurityAttributes = [System.Collections.ArrayList]::new()
    }

    $Policy.applicationRestrictions.identifierUris.nonDefaultUriAddition.excludeActors.customSecurityAttributes += $CsaExemption

    Update-ApplicationManagementPolicy -PolicyType "Tenant" -Policy $Policy -WhatIf $whatIf
}
# SIG # Begin signature block
# MIIFxQYJKoZIhvcNAQcCoIIFtjCCBbICAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCD/Hj+cdJ1ra6Ik
# k/M3tyCoapqPKf2cjffNk+obxOZUWqCCAzowggM2MIICHqADAgECAhBuQViVGZw2
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
# gjcCARUwLwYJKoZIhvcNAQkEMSIEINXXBYiM39kCPXfclHly3U55l3ToTAG0Ag/d
# gCRNjm8MMA0GCSqGSIb3DQEBAQUABIIBAA9Aw0YPmO1RvcHccgrFNjeNHoW2SAJg
# z+ge8Vb2RIfdFvre92iQCi2mdcX9vSMCokBRrpcdJBdBo/xh5BNDVH4zbPFjUyCP
# 5bFMmxK3XmxttA7nDXXaMsya/lOZqBltdTKGe3uboGJIFoqqXE2FpPxuKlz6C8RE
# o+OGWGuN4ppF72xcfthTJ2D7T3K80XPaVORwtK7gFAoYcBrWgzNi+O4JcNGVoaJO
# GgIAhxO3u4+bN4MLDFe4jQ/gVoOAMaUeoe+j31si0wI+/2pDxm2bHeLNpaQiMeIl
# gLAMU6JCNIWxe9FN6Vb8QUhfC8uncU6UyVwycCNujUkLZMRULIjMfLQ=
# SIG # End signature block
