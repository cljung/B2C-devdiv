# Creating Users via Microsoft Graph API

Often the question is asked whether you can create users any other way than via the self-service signup. If you have looked at or done lab [6-migration](/6-migration) you know that you can. This sample is a deeper dive into [Microsoft Graph API](https://docs.microsoft.com/en-us/graph/use-the-api) and how you can use it to create your Azure AD B2C users. There is an online query tool called [Graph Explorer](https://developer.microsoft.com/en-us/graph/graph-explorer) that you can use to practice your queries. This sample will show you how you can create a user object, with extension attributes, with the MFA phone number ready to use. It also shows you how to create a group object and make the test user member of.

In the [src](src) folder, you have a DotNet Console program that makes the same GraphAPI queries, if you prefere to use DotNet.

## Microsoft Graph Query and Powershell
Working with Microsoft Graph API from the Powershell command prompt is all about using the `Invoke-RestMethod` with the correct Url,  payload and authentication header, since the Graph API is just a REST API which means you can invoke it from any tool or platform that is capable of making HTTP(s) calls. On Mac/Linux, this would probably mean using `curl`, but this sample is based on Powershell. If you're not on Windows, you have to install [Powershell for Mac](https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell-core-on-macos?view=powershell-7). 

### Helper module
This sample contanis a [helper powershell module](GrapiAPI-Helper.psm1) for working with Graph API. It is by all means not complete and its aim is just to show you how easy it is to work with Graph API and Azure AD B2C. You need to import the module to make use of the commands in it.

```powershell
import-module .\GraphAPI-Helper
```
If you look into the source file of the helper you will see that there are a few low level functions called `Invoke-GraphRestMethodGet`, `Invoke-GraphRestMethodPost`, etc, that handles the actual invokation of the REST APIs. Then there are some more function-oriented commands named `New-GraphUser`, `New-GrapGroup`, etc, who are responsible for formatting the correct URL and payload if it is a POST request.

### Getting an access token
Getting an access token that you can use is more difficult than you think, because it requires registering an app and finding some interactive way of launching the authorization flow. An easy way could also be using `client credentials`, but here I use my own userid and the device login flow. In the [helper powershell module](GrapiAPI-Helper.psm1), I have created a command called `Connect-GraphDevicelogin` that acquires and access token for you with your own credentials using the devicelogin flow. If you already are loggin to portal.azure.com for your B2C tenant, all you have to do is to paste the device code when asked. The device code is automatically put on the clipboard, so all you need to do is to do Ctrl+V and press next.

```powershell
Connect-GraphDevicelogin -TenantName "yourtenant.onmicrosoft.com" -Scope "Users.ReadWrite.All Groups.ReadWrite.All Applications.ReadWrite.All UserAuthenticationMethod.ReadWrite.All"
```

![Device Login](/media/7-graphapi-devicelogin.png)

  
The command will store your token in a global variable `$global:tokens` and will create the authentication header needed in `$global:authHeader`, so you need not worry about typing them in every command. 

### Creating a test user

To make the lab more real, we start with creating an extension attribute that will store additional data on the user objects. For this we need the existing application named `b2c-extensions-app` since extension attributes are created in the namespace of an application. We save the attribute names in variables since we need to reference them when creating the user object.

```powershell
# Get b2c-extensions-app - we need it to create extension attributes since AAD extensions have a namespace of an app
$b2cExtensionsApp = (Get-GraphApp "b2c-extensions-app").value

# create extension attributes
$LoyalityNumberAttrName = (New-GraphExtensionAttribute "LoyalityNumber" $b2cExtensionsApp "String").name
$MemberstipStatusAttrName = (New-GraphExtensionAttribute "MembershipStatus" $b2cExtensionsApp "String").name
```

The command `New-GraphUser` will create a new user object. The standard user attributes are passed as parameters like `-DisplayName`, but additional attributes to store are passed in a dictionary in key/value pairs. In the below case it is the extension attributes that are being passed this way, but you could set values for standard attributes like `city` and `streetAddress` this way too. 

```powershell
# create a user
[hashtable]$extAttrs = @{$LoyalityNumberAttrName="123456789"; $MemberstipStatusAttrName="Gold"}

$newuser = New-GraphUser -email "alice@contoso.com" -Password $superSecretPassword `
                        -DisplayName "Alice Contoso" -Surname "Contoso" -GivenName "Alice" -MobilePhone "+14255551212" `
                        -ExtensionAttributes $extAttrs `
                        -EnablePhoneSignin

# add phone number that can be used for sending OTP to the phone number
Set-GraphUserStrongAuthPhoneNumber $newuser.id $newuser.mobilePhone
```
The parameter `-EnablePhoneSignin` means that the command will make it possible to use your phone number as a username. This is not Phone-based authentication with OTP. It is just a way to use your phone number to identify yourself. The user object will have this stored

```json
    "identities": [
    {
        "signInType": "phoneNumber",
        "issuer": "yourtenant.onmicrosoft.com",
        "issuerAssignedId": "+14255551212"
    },
    {        
       ...
```

![Device Login](/media/7-graphapi-phonesignin.png)

The command `Set-GraphUserStrongAuthPhoneNumber` will update the `strongAuthenticationPhoneNumber` that is needed by Azure MFA to send OTP (one-time-passcodes) as SMS text messages or do dialbacks for MFA. So a true phone based authentication policy in B2C is based on a combination of storing the phone number in the `identities` collection and also update the `strongAuthenticationPhoneNumber` with the same phone number. If you where using Twilio, for example, you would not need the update the `strongAuthenticationPhoneNumber` value.

### Trace output 
To understand what is actually being sent to the Graph API, the helper functions echo out the URL and payload body in each call. Your output in the console would therefor be



```Powershell
PS > $b2cExtensionsApp = (Get-GraphApp "b2c-extensions-app").value

GET https://graph.microsoft.com/beta/applications?$filter=startswith(displayName,'b2c-extensions-app')

PS > $LoyalityNumberAttrName = (New-GraphExtensionAttribute "LoyalityNumber" $b2cExtensionsApp "String").name

POST https://graph.microsoft.com/beta/applications/982520ae-0d5b-40d9-ad0d-27bb78c9befe/extensionProperties
    {
        "name": "LoyalityNumber",
        "dataType": "String",
        "targetObjects": [ "User"]
    }

PS > $MemberstipStatusAttrName = (New-GraphExtensionAttribute "MembershipStatus" $b2cExtensionsApp "String").name

POST https://graph.microsoft.com/beta/applications/982520ae-0d5b-40d9-ad0d-27bb78c9befe/extensionProperties
    {
        "name": "MembershipStatus",
        "dataType": "String",
        "targetObjects": [ "User"]
    }

PS > $newuser = New-GraphUser -email "alice@contoso.com" -Password $superSecretPassword `
                        -DisplayName "Alice Contoso" -Surname "Contoso" -GivenName "Alice" -MobilePhone "+14255551212" `
                        -ExtensionAttributes $extAttrs `
                        -EnablePhoneSignin

POST https://graph.microsoft.com/beta/users
        {
          "accountEnabled": true,
          "creationType": "LocalAccount",
          "displayName": "Alice Contoso",
          "surname": "Contoso",
          "givenname": "Alice",
          "mobilePhone": "+14255551212",
          "passwordPolicies": "DisablePasswordExpiration,DisableStrongPassword",
          "passwordProfile": {
            "password": "**********************",
            "forceChangePasswordNextSignIn": false
          },
          "extension_19bd6154844c4905881c5e07d9aee753_MembershipStatus": "Gold",
          "extension_19bd6154844c4905881c5e07d9aee753_LoyalityNumber": "123456789",

          "identities": [
            {
              "signInType": "emailAddress",
              "issuer": "yourtenant.onmicrosoft.com",
              "issuerAssignedId": "alice@contoso.com"
            },
            { 
              "signInType": "phoneNumber", 
              "issuer": "yourtenant.onmicrosoft.com", 
              "issuerAssignedId": "+14255551212" }

          ]
        }

PS > Set-GraphUserStrongAuthPhoneNumber $newuser.id $newuser.mobilePhone

POST https://graph.microsoft.com/beta/users/9573339b-e5dd-41c1-9368-7c995d51a073/authentication/phoneMethods
        {
            "phoneType": "mobile",
            "phoneNumber": "+14255551212"
        }

PS > $newgroup = New-GraphGroup "SalesAdmin"

POST https://graph.microsoft.com/beta/groups
    {
        "description": "SalesAdmin",
        "displayName": "SalesAdmin",
        "securityEnabled": true,
        "mailEnabled": false,
        "mailNickname": "SalesAdmin"
    }

PS > New-GraphGroupMember $newgroup.id $newuser.id 

POST https://graph.microsoft.com/beta/groups/73753dd5-9c66-4dd6-99cc-84b33611ce62/members/$ref
    {
        "@odata.id": "https://graph.microsoft.com/beta/directoryObjects/9573339b-e5dd-41c1-9368-7c995d51a073"
    }

```

### Refreshing the Access Token

The access token is valid for one hour and if you work longer that that you will receive access denied which means it is time to refresh the access token. In the Graph API helper module, there is a command named `Refresh-GraphAccessToken` that will do that for you.

```Powershell
Refresh-GraphAccessToken
```