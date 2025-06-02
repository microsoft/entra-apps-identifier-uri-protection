# Enable alternate identifier URI restriction

Microsoft Entra ID has released a secondary protection, available in [app management policies](https://learn.microsoft.com/en-us/graph/api/resources/applicationauthenticationmethodpolicy?view=graph-rest-beta), that you can enable to block the addition of all custom identifier URIs (also referred to as app ID URIs) to v1 app registrations. Enabling this protection is recommended and will improve the security of your tenant.  The rest of this document will cover:

- How to enable this protection
- The behavior you should expect when you enable it, and how it differs from the [primary protection](./README.md)
- How to grant exemptions if/when needed

## Prerequisites

Follow the same prerequisites from the [ReadMe](./README.md#prerequisites).

## Check if the protection is enabled

> [!NOTE]
> Before following these steps, make sure you've followed the [prerequisites](#prerequisites).

To check if the protection is enabled in your tenant, run this PowerShell command:

```PowerShell
./CheckIdentifierUriProtectionState.ps1 -Restriction "nonDefaultUriAddition"
```

When prompted, sign in with your administrator account.  The state of the protection in your tenant will be printed to the console.

## Disable the protection

> [!NOTE]
> Before following these steps, make sure you've followed the [prerequisites](#prerequisites).

To disable this protection, run this command:

```PowerShell
./DisableIdentifierUriProtection.ps1 -Restriction "nonDefaultUriAddition"
```

When prompted, sign in with your administrator account.

Once the above command is executed successfully, the protection will be disabled.

## Enable the protection

> [!NOTE]
> Before following these steps, make sure you've followed the [prerequisites](#prerequisites).

To enable the protection, run this PowerShell command:

```PowerShell
./EnableIdentifierUriProtection.ps1 -Restriction "nonDefaultUriAddition"
```

When prompted, sign in with your administrator account.

Once the above command is executed successfully, the protection will be enabled.   Read on to understand the behavior to expect in your tenant once this protection is enabled how to grant exemptions to the protection if/when needed.

## What to expect

This protection is available through [app management policies](https://learn.microsoft.com/en-us/graph/api/resources/applicationauthenticationmethodpolicy?view=graph-rest-beta).   Specifically, it is enabled by setting the [`nonDefaultUriAddition` restriction](https://learn.microsoft.com/en-us/graph/api/resources/identifieruriconfiguration?view=graph-rest-beta) in app management policies.

Once this protection is enabled, new identifier URI that are added to v1.0 Entra applications must come in the default format of either `api://{appId}` or `api://{tenantId}/{appId}`. Custom URIs are not accepted on v1 applications. New identifier URIs can still be added if any of the following criteria is met:

- The identifier URI being added to the app is one of the 'default' URIs, meaning it is in the format of `api://{appId}` or `api://{tenantId}/{appId}`
- The app accepts v2 tokens.  This is true if the app's `api.requestedAccessTokenVersion` property is set to `2`.
- The app is a SAML app.  This is true if the service principal for the app has its `preferredSingleSignOnMode` property set to `SAML`.
- An [exemption has been granted](#how-to-grant-exemptions) to the app the URI is being added to, or to the user or service performing the update.

**Existing identifier URIs already configured on the Entra app won't be affected, and all apps will continue to function as normal.  This will only affect new updates to Entra app configurations.**

### Impact on developers in your tenant

Users in your tenant who own resource applications (typically the API developer) won't be able to add new custom identifier URIs to their Entra app configurations.  If they try, they'll receive an error like:

```txt
The newly added URI XXXXX must comply with the format 'api://{appId}' or 'api://{tenantId}/{appId}' as per the default app management policy of your organization. If the requestedAccessTokenVersion is set to 2, this restriction may not apply. See https://aka.ms/identifier-uri-addition-error for more information on this error.
```

This means that the API developer can't add any new custom string identifiers for their API.  If a client wants to call the API, they'll have to use an existing identifier already configured on the app, or one of the default identifiers (`api://{appId}` or `api://{tenantId}/{appId}`). 

### Impact on scripts and services that modify Entra apps

If your organization owns or uses a service that programmatically creates or updates Entra applications with identifier URIs (likely using the [Microsoft Graph application API](https://learn.microsoft.com/en-us/graph/api/resources/application)), that might also be affected by this policy.  This includes automations like Powershell and CLI scripts.

In this scenario, we recommend updating the script, service, or process code to set the `requestedAccessTokenVersion` to `2` for Entra apps it creates or modifies.  That way, the service can continue adding identifier URIs programmatically without issue.  However, until that update can be made, there are two ways you can unblock these services.

1. If the service adding identifier URIs makes its API calls to Microsoft Graph using delegated permissions, where API operations are performed on behalf of a user, you can [grant exemptions](#grant-a-user-service-or-process-an-exemption) to trusted individuals in your tenant.  When these individuals use the service, it will continue to work as it did before.
1. You can also grant the entire service or process an exemption.  This means the service will continue functioning as it did before, regardless of who is using it (even if there is no signed-in user). Do this by assigning the [service principal](https://learn.microsoft.com/en-us/graph/api/resources/serviceprincipal?view=graph-rest-1.0) that represents the service in your tenant an exemption, using the steps for [granting a caller an exemption](#grant-a-user-service-or-process-an-exemption). Please note it is only safe to do so if the service generates the identifier URI values it adds to app registrations. Exemptions should not be provided to services or processes that accept an identifier URI value as an input. 

## How to grant exemptions

> [!NOTE]
> Before following these steps, make sure you've followed the [prerequisites](#prerequisites).

If there is an important business scenario blocked by this protection, you can use exemptions to unblock the trusted scenario while keeping your tenant secure.  We strongly recommend using exemptions if you encounter issues enabling the protection, rather than turning off the protection altogether. 

### Grant an app an exemption

The most common exemption you will likely need to grant is to a specific app.  When you grant an app an exemption, it will be able to have identifier URIs added to it, even if the policy would normally otherwise block it.

```PowerShell
./GrantAppExemption -Restriction "nonDefaultUriAddition" -AppId {AppIdOfAppToBeGrantedExemption}
```

See [grant an app exemption](/grant-app-exemption.md) to learn how to make this same change using the Microsoft Graph API.

### Grant a user, service, or process an exemption

You might encounter a scenario where you need to grant a specific caller an exemption to this protection.   When you grant a caller an exemption, all of the Entra app creation and update operations done by that user or service will be exempt from rules blocking identifier URI addition, regardless of which app is being created or updated.  

#### Additional prerequisites

To grant this exemption, you need two directory roles, in addition to the `Global Administrator`, `Application Administrator`, or `Cloud App Administrator` role from [Prerequisites](#prerequisites):

- [Attribute Definition Administrator](https://learn.microsoft.com/en-us/entra/identity/role-based-access-control/permissions-reference#attribute-definition-administrator)
- [Attribute Assignment Administrator](https://learn.microsoft.com/en-us/entra/identity/role-based-access-control/permissions-reference#attribute-assignment-administrator)

See [Assign Microsoft Entra roles to users](https://learn.microsoft.com/en-us/entra/identity/role-based-access-control/manage-roles-portal) to learn how to grant directory roles.

#### Grant the exemption

```PowerShell
./GrantCallerExemption -Id {IdOfUserOrServicePrincipal} -Restriction "nonDefaultUriAddition"
```

Once this completes, the user or service principal will be able to add an identifier URI to any app they have access to.

This operation will create a [custom security attribute](https://learn.microsoft.com/en-us/entra/fundamentals/custom-security-attributes-overview) in your tenant, and assign it to the user or service principal.  If you would rather use an existing custom security attribute from your tenant, run this command instead:

```PowerShell
./GrantCallerExemption -Restriction "nonDefaultUriAddition" -Id {IdOfUserOrServicePrincipal} -CustomSecurityAttributeSet {AttributeSetName} -CustomSecurityAttributeName {AttributeName} -CustomSecurityAttributeValue {AttributeValue}
```

