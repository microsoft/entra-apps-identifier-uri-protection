# Grant a caller an exemption

Granting a caller an exemption involves three steps:

1. [Creating a custom security attribute definition](#create-a-custom-security-attribute-definition)
1. [Including the custom security attribute as an exemption indicator in your policy](#add-the-custom-security-attribute-as-an-exemption-indicator)
1. [Stamping the attribute on the user or service principal](#assign-the-custom-security-attribute-to-a-user-or-service-principal)

## Prerequisites

To follow these steps, you need two directory roles, in addition to the `Global Administrator` or `Application Administrator` role from [Prerequisites](#prerequisites):

- [Attribute Definition Administrator](https://learn.microsoft.com/en-us/entra/identity/role-based-access-control/permissions-reference#attribute-definition-administrator)
- [Attribute Assignment Administrator](https://learn.microsoft.com/en-us/entra/identity/role-based-access-control/permissions-reference#attribute-assignment-administrator)

## Create a custom security attribute definition

This caller-based exemption is done through [custom security attributes](https://learn.microsoft.com/en-us/entra/fundamentals/custom-security-attributes-overview).  Custom security attributes are key-value pairs; they require a definition for the key-value pair to be created in the tenant, and then instances of the key-value pair can be added to specific users or service principals.

Custom security attribute definitions can be [created through the Entra portal](https://learn.microsoft.com/en-us/entra/fundamentals/custom-security-attributes-add), but you can also do so using Microsoft Graph.  First, [create an attribute set](https://learn.microsoft.com/en-us/graph/api/directory-post-attributesets) (if you don't have one already).   Attribute sets are containers for custom security attribute definitions.

```http
POST https://graph.microsoft.com/v1.0/directory/attributeSets 
{
    "id":"PolicyExemptions",
    "description":"Attributes for granting exemptions to policy",
    "maxAttributesPerSet":25
}
```

Then, [create the definition](https://learn.microsoft.com/en-us/graph/api/directory-post-customsecurityattributedefinitions).

```http
POST https://graph.microsoft.com/v1.0/directory/customSecurityAttributeDefinitions
{
    "attributeSet": "PolicyExemptions",
    "description": "Active projects for user",
    "isCollection": false,
    "isSearchable": true,
    "name": "AppManagementExemption",
    "status": "Available",
    "type": "String",
    "usePreDefinedValuesOnly": true,
    "allowedValues": [
        {
            "id": "ExemptFromIdentifierUriFormattingRestriction",
            "isActive": true
        }
    ]
}
```

These are just example values; you can name your custom security attribute anything you like.  However, make sure that the custom security attribute definition you create is of `String` type, and `isCollection` is set to `false`.  Currently, single-value string types are the only custom security attributes supported as exemption indicators in app management policies.

## Add the custom security attribute as an exemption indicator

This step must be done using Microsoft Graph.

```http
PATCH https://graph.microsoft.com/beta/policies/defaultAppManagementPolicy

 {  
    "applicationRestrictions": {
        "identifierUris": {
            "uriAdditionWithoutUniqueTenantIdentifier": {
                "state": "enabled",
                "excludeAppsReceivingV2Tokens": true,
                "excludeSaml": true,
                "excludeActors": {
                    "customSecurityAttributes": [
                        {
                            "@odata.type": "microsoft.graph.customSecurityAttributeStringValueExemption",
                            "id": "PolicyExemptions_AppManagementExemption",  //This `id` value is the concatenation of "AttributeSet_AttributeName"
                            "operator": "equals",
                            "value": "ExemptFromIdentifierUriFormattingRestriction"
                        }
                    ]
                }
            }
        },
        ... //Other restrictions here
    }
 }
```

This indicates to Microsoft Entra that you want users or service principals with that specific custom security attribute value assigned to them to be exempt from the policy.

## Assign the custom security attribute to a user or service principal

Custom security attributes can be assigned to both [users](https://learn.microsoft.com/en-us/entra/identity/users/users-custom-security-attributes) and [service principals](https://learn.microsoft.com/en-us/entra/identity/enterprise-apps/custom-security-attributes-apps) through the Entra portal, but you can also do so using Microsoft Graph. 

To assign to a user:

```http
PATCH https://graph.microsoft.com/v1.0/users/{id}
{
    "customSecurityAttributes":
    {
        "Engineering":
        {
            "@odata.type":"#Microsoft.DirectoryServices.CustomSecurityAttributeValue",
            "AppManagementExemption":"ExemptFromIdentifierUriFormattingRestriction"
        }
    }
}
```

To assign to a service principal:

```http
PATCH https://graph.microsoft.com/v1.0/servicePrincipals/{id}
{
    "customSecurityAttributes":
    {
        "Engineering":
        {
            "@odata.type":"#Microsoft.DirectoryServices.CustomSecurityAttributeValue",
            "AppManagementExemption":"ExemptFromIdentifierUriFormattingRestriction"
        }
    }
}
```

Replace {id} with the object ID of the user or service principal.

Once this completes, the user(s) or service principal(s) with the custom security attribute assigned will be able to add an identifier URI to any app they have access to.
