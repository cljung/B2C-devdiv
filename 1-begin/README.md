# B2C Identity Experience Framework setup via scripts

This sample shows how to quickly setup Identity Experience Frameork using the B2C Powershell Module that exists in [this repo](https://github.com/cljung/AzureAD-B2C-scripts). The documentation for how to create a B2C tenant is available [here](https://docs.microsoft.com/en-us/azure/active-directory-b2c/tutorial-create-tenant), and you don't need to continue with the [Get started with custom policies](https://docs.microsoft.com/en-us/azure/active-directory-b2c/custom-policy-get-started?tabs=applications#custom-policy-starter-pack) manually as these scripts in this readme file will do that for you. At the end of this sample, you have a working B2C Custom Policy and it will take you less than 5 minutes to have it deployed.

## B2C Powershell Module - Install
As mentioned, the [B2C Powershell Module](https://github.com/cljung/AzureAD-B2C-scripts) exists here and in order to use it, you need to `git clone` it and you need to either install the Azure Az powershell module on Windows. If you are on a Mac, you need to install [Powershell Core](https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell-core-on-macos). 


```powershell
# open a powershell command prompt (Win-key, powershell)
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
if ($null -eq (get-module Az.Accounts)) {
    Install-Module -Name Az.Accounts -Scope CurrentUser -Repository PSGallery -Force
    Import-Module -Name Az.Accounts
}
# close this command prompt and continue to work as a normal user
```

```powershell
git clone https://github.com/cljung/AzureAD-B2C-scripts.git
cd AzureAD-B2C-scripts
import-module .\Az.ADB2C.psm1
```
If you don't have `git` installed, you can installed from here [link](https://git-scm.com/download/win). You can also download the powershell module from github as a zipfile from this [link](https://github.com/cljung/AzureAD-B2C-scripts/archive/refs/heads/master.zip).
 
Then you need to complete the install. It is described in the other repo, but the steps are repeated here.

```powershell
Connect-AzADB2CDevicelogin -TenantName "yourtenant.onmicrosoft.com" -Scope "Directory.ReadWrite.All"
New-AzADB2CGraphApp -n "B2C-Graph-App" -CreateConfigFile
# at this point, find B2C-Graph-App in portal.azure.com/yourtenant.onmicrosoft.com and grant consent to the app before continuing
New-AzureADB2CLocalAdmin -u "graphexplorer" -RoleNames @("Global Administrator")
Start-AzADB2CPortal
```

**Before you continue, in the Azure Portal, find the `B2C-Graph-App` under App Registrations, goto API Permissions and grant admin consent for the App. If you don't, following commands will fail**

If the creation of the `graphexplorer` LocalAdmin user throws any kind of error, please go into the portal, to `Roles and administrators`, find `Global administrator` and make the `graphexplorer` a global admin.

If you haven't already completed the setup of Identity Experience Framework in your B2C tenant, run this command to complete it.
```powershell
Enable-AzADB2CIdentityExperienceFramework -n "ABC-WebApp" -f "abc123"
```

## Creating a new B2C Custom Policy Project

Starting a new B2C Custom Policy project with the ***B2C Powershell Module*** is very easy. You just run the following command.

```powershell
New-AzADB2CPolicyProject -PolicyPrefix "t1"
```

Now you have local policy files on your laptop that are ready to be uploaded. Run the Push command to upload them. The Push command will read the xml policy files, determind the correct order to upload them (base first, etc) and then use GraphAPI to upload them.

```powershell
Import-AzADB2CPolicyToTenant
```

Once the policies are uploaded, you can use the Test command to launch a browser to run an authorize flow. It will start the default browser on your laptop. If you want to start a different browser you pass the `-Firefox`, `-Edge` or `-Chrome` argument. 

```powershell
Test-AzADB2CPolicy -n "ABC-WebApp" -p .\SignUpOrSignin.xml
```
