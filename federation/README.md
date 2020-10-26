# B2C Federation with AzureAD

This sample shows how to quickly setup federation using the B2C Powershell Module that exists in [this repo](https://github.com/cljung/AzureAD-B2C-scripts). The documentation for how to configure federation with Azure AD is available [here](https://docs.microsoft.com/en-us/azure/active-directory-b2c/identity-provider-azure-ad-single-tenant-custom), but this github repo will show you how to do it via script.

![AzureAD Claims Provider selectcion](/media/fed-page-1.png)

![AzureAD Signin page](/media/fed-page-2.png)


## B2C Powershell Module - Install
As mentioned, the [B2C Powershell Module](https://github.com/cljung/AzureAD-B2C-scripts) exists here and in order to use it, you need to `git clone` it and you need to either install the AzureAD powershell module on Windows or install Azure CLI on a Mac. 

```powershell
# open a powershell command prompt as Administrator (Win-key, powershell, Run as Admin)
if ($null -eq (get-module AzureAD)) {
    Install-Module -Name AzureAD
}
```

```powershell
git clone https://github.com/cljung/AzureAD-B2C-scripts.git
cd AzureAD-B2C-scripts
import-module .\AzureADB2C-Scripts.psm1
```

Then you need to complete the install. It is described in the other repo, but the steps are repeated here.

```powershell
Connect-AzureADB2CEnv -t "yourtenant"
New-AzureADB2CGraphApp -n "B2C-Graph-App" -CreateConfigFile
New-AzureADB2CLocalAdmin -u "graphexplorer" -RoleNames @("Company Administrator")
Start-AzureADB2CPortal
# find B2C-Graph-App and grant permission to the app before continuing
```

If you haven't already completed the setup of Identity Experience Framework in your B2C tenant, run this command to complete it.
```powershell
Enable-AzureADB2CIdentityExperienceFramework -n "ABC-WebApp" -f "abc123"
```

## Creating a new B2C Custom Policy Project

Starting a new B2C Custom Policy project with the ***B2C Powershell Module*** is very easy. You just run the following command.

```powershell
New-AzureADB2CPolicyProject -PolicyPrefix "fed"
```

In order to test that they are working before you go any further, do the following and make sure it uploads correct and that you can sign in with a local account.

```powershell
Push-AzureADB2CPolicyToTenant
Test-AzureADB2CPolicy -n "ABC-WebApp" -p .\SignUpOrSignin.xml
```

## Register an application in Azure AD for federation

Follow the documentation on how to [Register an Azure AD app](https://docs.microsoft.com/en-us/azure/active-directory-b2c/identity-provider-azure-ad-single-tenant-custom?tabs=app-reg-ga#register-an-azure-ad-app). The name of the app is not important, but you need to make sure you get these things right:

- Accounts in this organizational directory only
- Redirect Uri must be `https://your-B2C-tenant-name.b2clogin.com/your-B2C-tenant-name.onmicrosoft.com/oauth2/authresp`
- Create an App secret

## Adding a Claims Provider for Azure AD

First, we need to add the client secret for the AzureAD application. This is done via the following command.

```powershell
New-AzureADB2CPolicyKey -KeyContainerName "B2C_1A_FabrikamAppSecret" -KeyType "secret" -KeyUse "sig" -Secret $yoursecret
```

The, we need to add the ClaimsProvider for AzureAD. Note that the AadTenantName (before the dot) needs match the part of the KeyContainerName above. If you have a AadTenantName of contoso.com, the KeyContainerName must be B2C_1A_ContosoAppSecret. 

The $AppId is the AppId (client_id) of the application you registered in AzureAD.

```powershell
Set-AzureADB2CClaimsProvider -ProviderName "AzureAD" -AadTenantName "fabrikam.com" -client_id $AppId
```

Open the file `TrustFrameworkExtensions.xml` in Visual Studio Code and make the following changes.

- Find `<Item Key="METADATA">` and make sure it points to your tenant after `login.microsoftonline.com`.

Then save the file, upload the policies again to B2C and do another test run. Now you have 

```powershell
Push-AzureADB2CPolicyToTenant
Test-AzureADB2CPolicy -n "ABC-WebApp" -p .\SignUpOrSignin.xml
```

You should see something like the screenshots at top of this page.