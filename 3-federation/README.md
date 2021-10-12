# B2C Federation with AzureAD

This sample shows how to quickly setup federation using the B2C Powershell Module that exists in [this repo](https://github.com/cljung/AzureAD-B2C-scripts). The documentation for how to configure federation with Azure AD is available [here](https://docs.microsoft.com/en-us/azure/active-directory-b2c/identity-provider-azure-ad-single-tenant-custom), but this github repo will show you how to do it via script.

![AzureAD Claims Provider selectcion](/media/fed-page-1.png) ![AzureAD Signin page](/media/fed-page-2.png)


## B2C Powershell Module - Install
Quickly run through the [1-begin](./1-begin) lab to make sure you have configured the B2C Identity Experience Framework.

## Creating a new B2C Custom Policy Project

Starting a new B2C Custom Policy project with the ***B2C Powershell Module*** is very easy. You just run the following command.

```powershell
New-AzADB2CPolicyProject -PolicyPrefix "fed"
```

In order to test that they are working before you go any further, do the following and make sure it uploads correct and that you can sign in with a local account.

```powershell
Import-AzADB2CPolicyToTenant
Test-AzADB2CPolicy -n "ABC-WebApp" -p .\SignUpOrSignin.xml
```

## Register an application in Azure AD for federation

Follow the documentation on how to [Register an Azure AD app](https://docs.microsoft.com/en-us/azure/active-directory-b2c/identity-provider-azure-ad-single-tenant-custom?tabs=app-reg-ga#register-an-azure-ad-app). The name of the app is not important, but you need to make sure you get these things right:

- Accounts in this organizational directory only
- Redirect Uri must be `https://your-B2C-tenant-name.b2clogin.com/your-B2C-tenant-name.onmicrosoft.com/oauth2/authresp`
- Create an App secret

Also, make sure you go into `Token configuration` to add email, family_name and given_name to your AzureAD token. The B2C policy is designed to pickup these claims and if AzureAD can give you this information, why would you bother the user filling it in.

![Token Configuration](/media/fed-page-3.png)

## Adding a Claims Provider for Azure AD

First, we need to add the client secret for the AzureAD application. This is done via the following command.

```powershell
New-AzADB2CPolicyKey -KeyContainerName "B2C_1A_FabrikamAppSecret" -KeyType "secret" -KeyUse "sig" -Secret $yoursecret
```

Then, we need to add the ClaimsProvider for AzureAD. Note that the AadTenantName (before the dot) needs match the part of the KeyContainerName above. If you have a AadTenantName of contoso.com, the KeyContainerName must be B2C_1A_ContosoAppSecret. 

The $AppId is the AppId (client_id) of the application you registered in AzureAD.

```powershell
Set-AzADB2CClaimsProvider -ProviderName "AzureAD" -AadTenantName "fabrikam.com" -client_id $AppId
```

Open the file `TrustFrameworkExtensions.xml` in Visual Studio Code and make the following changes.

- Find `<Item Key="METADATA">` and make sure it points to your tenant after `login.microsoftonline.com`.

Then save the file, upload the policies again to B2C and do another test run.  

```powershell
Import-AzADB2CPolicyToTenant
Test-AzADB2CPolicy -n "ABC-WebApp" -p .\SignUpOrSignin.xml
```

You should see something like the screenshots at top of this page.

## GraphAPI 

Once you've signed in with a federated AzureAD user for the first time, it's time to use Graph Explorer to check out how B2C stores the federated user data. In order to do that, do the following

1. Launch [Microsoft Graph Explorer](https://developer.microsoft.com/en-us/graph/graph-explorer)
1. Sign in with the local admin you created, ie `graphexplorer@yourtenant.onmicrosoft.com`. Signing in with another user might lead you to another tenant.
1. Change the query to `https://graph.microsoft.com/v1.0/users/?$select=id,displayName,identities` and press `Run Query`. You might need to Modify Permissions in order to run the query.
1. Search for the user you created (Ctrl+F will do good on the query result). 

You should see something like below. The `identities` collection will hold a `signInType` with the value of `federated` that points back to your AzureAD tenant. The `issuerAssignedId` is the objectId of your user in the AzureAD tenant. 

```json
"id": "8b4dd578-cb56-4a90-945d-b02c8b982bd0",
"displayName": "Megan Bowen",
"identities": [
    {
        "signInType": "federated",
        "issuer": "https://login.microsoftonline.com/aabf2e33-ab5c-49ac-8f62-81af9596e434/v2.0",
        "issuerAssignedId": "c30fb0d0-d9a5-47ef-ae09-6902a9a06021"
    },
    {
        "signInType": "userPrincipalName",
        "issuer": "yourtenant.onmicrosoft.com",
        "issuerAssignedId": "cpim_bfea5eec-e634-4c7f-b36f-cc06aca16bff@yourtenant.onmicrosoft.com"
    }
]
},
```