# Enable the restriction using Microsoft Graph

To enable the restriction, make the following two requests in Microsoft Graph.

First, fetch the existing [default app management policy](https://learn.microsoft.com/en-us/graph/api/resources/tenantappmanagementpolicy?view=graph-rest-beta) configured in your tenant.

```http
GET https://graph.microsoft.com/beta/policies/defaultAppManagementPolicy
```

Copy the response.  For example:

```json
{
    "id": "9eedc333-2700-42b1-8980-2fda146400b6",
    "displayName": "Default app management tenant policy",
    "description": "Default tenant policy that enforces app management restrictions on applications and service principals. To apply policy to targeted resources, create a new policy under appManagementPolicies collection.",
    "isEnabled": false,
    "applicationRestrictions": {
        "audiences": null,
        "identifierUris": null,
        "passwordCredentials": [],
        "keyCredentials": []
    },
    "servicePrincipalRestrictions": {
        "passwordCredentials": [],
        "keyCredentials": []
    }
}
```

Send a request updating the app management policy.  When you do so, include any existing restrictions that are already set, but also enable the `uriAdditionWithoutUniqueTenantIdentifier` restriction under `identifierUris`. Make sure you also enable the default policy in your tenant, by setting `isEnabled` to `true`:

```http
PATCH https://graph.microsoft.com/beta/policies/defaultAppManagementPolicy
{
    "isEnabled": true,
    "applicationRestrictions": {
        "audiences": null,
        "identifierUris": {
            "uriAdditionWithoutUniqueTenantIdentifier": {
                "state": "enabled", 
                "excludeAppsReceivingV2Tokens": true,
                "excludeSaml": true
            }
        }
        "passwordCredentials": [], //replace with existing restrictions already set in ‘passwordCredentials’, if any
        "keyCredentials": [] //replace with existing restrictions already set in ‘keyCredentials’, if any
    }
}
```
