# Evaluate the impact of enabling identifier URI protection

Microsoft recommends that all orgaizations enable the recently released [identifier URI protection](README.md).  However, enabling this policy may cause impact to admin and developer workflows in some organizations.  This page will describe how to identify impacted workflows, and recommendations on how to fix or exempt them, before enabling the policy.

## Identify impacted workflows

Identifying impacted workflows involves the following steps:

1. Identify Entra applications that were recently updated in a way that violates [the policy](README.md#what-to-expect)
1. Discuss how and why those applications had those identifier URIs added with the application owners
1. [Optional] Find the directory audit log events for recent app creation or update events in violation of the policy
1. Using the above information, identify the users or services with dependencies on this operation

### Identify updated applications

First, compile a list of application IDs that were recently created or updated in a way that violates the policy.  You can get this list of applications from the communication sent by Microsoft labeled `todo`.  The communication will list up to 20 app IDs of applications that were recently modified in a way that violates the policy.  If the communication contains less than 20 app IDs, then that list is the full set of modified applications Microsoft has recorded for your tenant.  If the communication contains 20 app IDs, you can get a longer list by [filing a support case](https://aka.ms/entrasupt).

Go to the [App registrations](https://aka.ms/ra/prod) experience to look up these applications by their app ID.  Input the application ID in the search bar.  If you can't find the application, it was likely deleted.

As a reminder, the applications in this list were updated in a way that violates the identifier URI policy.  This means they had an identifier URI (also known as app ID URI) added that does not comply with the [secure formats](../README.md#secure-formats).  You can view the full set of the application's `identifierUris` using the `Manifest` page.  You can also view one of the application's `identifierUris` using the `Expose an API` page.

For each application, identify the owner (using the `Owners` page) or other technical contact who can discuss how and why the application was updated.

If you can't find an app owner or techincal contact to discuss with, try [searching directory update logs](#optional-find-directory-update-events) instead.

### [Optional] Find directory update events

If you can't find an app owner or technical contact to discuss with by searching for the app in the [App registrations experience](https://aka.ms/ra/prod), then you can try searching your directory update logs for recent app creation or update events that would have been blocked, if the policy were turned on.  

You can do this using [directory audit logs](https://learn.microsoft.com/en-us/graph/api/directoryaudit-list?view=graph-rest-1.0&tabs=http).  Filter through the logs for instances where one of the impacted apps provided to you was updated.

To do this, you need the object ID of the updated application.  **This is a different value from the app ID.** You can retreive the object ID by searching for the application in the [App registrations experience](https://aka.ms/ra/prod).  The Object ID field can be found and copied from the `Overview` page.

```http
https://graph.microsoft.com/v1.0/auditLogs/directoryAudits?$filter=category eq 'ApplicationManagement' and targetResources/any(x:x/id eq '{objectIdOfUpdatedApplication}')
```

From the logs, identify who or what updated the application.  If the change was made by a user, discuss this change with that user.  If it was done by a service, without any user context, discuss this change with the owner of that service.  You can look up the owner of that service by searching for the service in [Enterprise applications](https://portal.azure.com/#view/Microsoft_AAD_IAM/StartboardApplicationsMenuBlade). 

### Discuss with application owners or technical contacts

For each application, understand why it had a noncompliant URI added.  Was it done as part of a business-critical process?  Will similar updates be required in the future, either to the same application or to other applications in the organization?  Discuss these questions with the app owner or technical contact.

If this type of activity won't be repeated in the future, you can disregard it.  Only future app management events will be impacted by the policy.  If these updates were part of an important workflow in your organization, and similar updates are likely to be required in the future, then Microsoft recommends that you update that workflow to no longer violate the policy. In the meantime, you can exempt it so it doesn't break while you apply the policy to the rest of your organization.  Jump to [fix or exempt impacted workflows](#fix-or-exempt-impacted-workflows).

## Fix or exempt impacted workflows 

You can either fix or exempt workflows that may make future requests blocked by the policy.

### Fix workflows

To fix them, ensure the workflow does one of the following when it configures the `identifierUris` property on Entra apps.

1. Ensure the URI follows the [formatting rules](../README.md#secure-formats), or
1. Update the app to accept [v2 tokens](https://aka.ms/identifier-uri-policy#guidance-for-developers)

### Exempt them

You can also exempt workflows, so you can apply the protection to the rest of your tenant while you work on updating impacted workflows.  You can configure exceptions on the [app(s) being updated](../README.md#grant-an-app-an-exemption), on the [users making the request(s)](../README.md#grant-a-user-service-or-process-an-exemption), or on the [service making the request](../README.md#grant-a-user-service-or-process-an-exemption).  

You can apply long-lived exceptions to admin users, or to services that set identifier URIs without accepting user input on what the URI should be.  Any other exception should be scoped and short-term.