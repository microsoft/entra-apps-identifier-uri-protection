# Grant an app an exemption

Granting an app an exemption involves two steps:

1. [Creating a custom policy](#create-a-custom-policy-one-time-step)
1. [Assigning the custom policy to the app](#assign-the-custom-policy-to-an-application)

## Create a custom policy (one-time step)

First, you need to create a custom policy that grants an exemption to the identifier URI restrictiction.  This is a one-time creation operation; you can re-use this custom policy for all apps that need an exemption.

Make the following requests in Microsoft Graph creating a custom [app management policy](https://learn.microsoft.com/en-us/graph/api/resources/appmanagementpolicy?view=beta):

```http
POST https://graph.microsoft.com/beta/policies/appManagementPolicies

{
    "isEnabled": true,
    "applicationRestrictions": {
        "identifierUris": {
            "uriAdditionWithoutUniqueTenantIdentifier": {
                "state": "disabled",
                "excludeAppsReceivingV2Tokens": true,
                "excludeSaml": true
            }
        }
    }
}
```

This will create a custom policy with the identifier URI addition restriction disabled. Copy the `id` property of the policy that is created; you'll use it in the next step. When this policy is assigned to an app, the disabled restriction will override the tenant default policy, meaning the app will be exempt from the restriction.

## Assign the custom policy to an application

[Assign the custom policy](https://learn.microsoft.com/en-us/graph/api/appmanagementpolicy-post-appliesto?view=graph-rest-beta&tabs=http) you just created to the app(s) you want to be exempted.

```http
POST https://graph.microsoft.com/beta/applications(appId='{appId}')/appManagementPolicies/$ref

{
 "@odata.id":"https://graph.microsoft.com/beta/policies/appManagementPolicies/{id}"
}
```

Replace `{appId}` with the appId of the app to be exempted, and `{id}` with the ID of the custom policy you just created.  Repeat this operation for each app you want to exempt.