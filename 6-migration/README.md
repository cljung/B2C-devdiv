# B2C User Migration

This sample shows how you can migrate users into Azure AD B2C from an external source.

![Overview](/media/migration-overview.png).

In the community github sample, there is a bigger sample called [signin-migration](https://github.com/azure-ad-b2c/samples/tree/master/policies/signin-migration) that shows you how you can migrate from AWS Cognito, OpenLDAP or from a CSV file via Azure Table Storage. This exercise will however just show you how to migrate from a CSV file via Azure Table Storage.

The architecture is that you have users in a CSV file that are imported to B2C and Azure Table Storage. B2C does not know the password and Table Storage holds a password hash. Only the user knows the password. (That the password is in clear text is just so you can select it for this exersice.)

The Azure Function serves two purposes; It is used to upload the contents of the CSV file to Table Storage and it is used by B2C to validate a userid and password during the first time a user signs in.

## CSV file with users

There is a sample CSV file named [newusers.csv](https://github.com/azure-ad-b2c/samples/blob/master/policies/signin-migration/table/scripts/newusers.csv) that contain information for two users `alice@contoso.com` and `bob@contoso.com`. Copy that file and make the following changes:

- Change the mobile phone number for alice and bob into a phone number of yours
- Add a third row where the email is an email you are in posession of. 

## Preparing the Azure Table Storage

The same CSV file needs to be imported to Azure Table Storage if you like to like to simulate seamless password migration. The idea is that you have migrated the user details, like displayName, etc, but the password is unknown and stored elsewhere (Table Storage). The B2C policy will during first signin check the `requiresMigration` flag and see it is `True` which in turn means making a REST API call to an Azure Function that uses Azure Table Storage and verifies the password.
 
If you don't have an Azure Storage account you can use, you need to create one in your Azure Subscription (not the B2C tenant). Make sure you specify this settings

- Location - pick a location that matches your B2C tenant location
- Account kind - StorageV2 (general purpose V2). Make sure you **not** pick the BlobStorage kind as it doesn't support Table Storage
- Replication - Select Locally-redundant storage (LRS) as the others are overkill

![StorageAccount](/media/StorageAccount1.png)

When the storage account is created, copy the storage `Conection String` from the `Access keys` menu item and save it somewhere as we need it later.

![StorageAccount2](/media/StorageAccount2.png)
 
## Deploying the Azure Function

The B2C policy needs help validating the userid/password externally and we will have an Azure Function as the REST API that B2C is going to call. This Azure Function contains code to interact with the Azure Table Storage we created above.

Create an Azure Function App runtime `.Net Core` and OS `Windows`. Make sure you select the same `Location` as your Azure Table Storage. 
![AzureFunction](/media/AzureFunction1.png)

Create an Azure Function name `TableStorageUser` of type `HttpTrigger` and deploy file [run.csx](https://github.com/azure-ad-b2c/samples/blob/master/policies/signin-migration/table/source-code/run.csx) to it.

![AzureFunction2](/media/AzureFunction2.png)

Create the file [function.proj](https://github.com/azure-ad-b2c/samples/blob/master/policies/signin-migration/table/source-code/function.proj) in the Azure Function. This file is needed so that nuget packages will be downloaded correctly. An easy way to create this file is to go to the Console for the Function App, change directory to your function, then do a `copy function.json function.proj`, then go back to the Function App code editor and paste in the right content.  

![AzureFunction3](/media/AzureFunction3.png)

Copy the ConnectString for the storage account and store it as Configuration Setting named `STORAGE_CONNECTSTRING` for the Azure Function. You'll find a button named `+ New application setting` and you set the `Name` to `STORAGE_CONNECTSTRING` and the `Value` to the storage connect string.

![AzureFunction4](/media/AzureFunction4.png)

Get the Function Url and save it somewhere as we will need to add it to the B2C policy configuration.

![AzureFunction4](/media/AzureFunction5.png)

## Connect to your B2C tenant

Open a powershell command prompt. Run the below command and login as your self to your tenant. The b2cAppSettings file gets created in step [1-begin](/1-begin), so you need to complete that step.

```powershell
Connect-AzADB2C -ConfigPath .\b2cAppSettings_<yourtenant>.json
```

## Import the CSV file to B2C

Before importing the users, we need to create two extension attributes. The `requiresMigration` flag will be `True` if we don't know the user's password the first time the user signs in which means we have to validate it externally of B2C. The `phoneNumberVerified` is a flag that if it is `True` means that the number is verified and we could potentially use it for MFA.  

To create the extension attributes

```powershell
New-AzADB2CExtensionAttribute -AttributeName "requiresMigration" -DataType "Boolean"
New-AzADB2CExtensionAttribute -AttributeName "phoneNumberVerified" -DataType "Boolean"
```

The next step is to get an access token that can be used for creatig the users via Microsoft Graph API. The DeviceLogin will open up your browser and ask you to type the code. You can type Ctrl+V and paste it from the clipboard as the command put it on the clipboard.

```powershell
Connect-AzADB2CDevicelogin -TenantId $global:TenantId -Scope "Directory.ReadWrite.All"
$access_token = $global:authHeader.Authorization.Split(" ")[1]
To sign in, use a web browser to open the page https://microsoft.com/devicelogin and enter the code C2SDABRH4 to authenticate.
```

To test that the access token works, you can issue the below command to list all users

```powershell
$resp = Invoke-RestMethod -Uri "https://graph.microsoft.com/v1.0/users" -Headers $global:authHeader -Method "GET" -ContentType "application/json"
$resp.value
```
Then run the import command as below. This will load the contents of the CSV file, then iterate over each record and make a POST to Graph API that will create the user object in B2C. If you like to import the password from the CSV file, you need to add the `-ImportPassword` switch. If you don't pass that switch, the password will be in Azure Table Storage (see below) and we will ask for external validation at first signin.

```powershell
.\import-users-from-csv.ps1 -t $global:tenantName -access_token $access_token -Delimiter ";" -f "...path-to-my-file...\newusers.csv"
```

## Import the CSV file to Azure Table Storage

The import script to Azure Table Storage can be found [here](https://github.com/azure-ad-b2c/samples/blob/master/policies/signin-migration/table/scripts/save-users-to-tablestorage.ps1). Copy it and replace the url to point to your Azure Function. Then you run the command like below.

```powershell
.\save-users-to-tablestorage.ps1 -Delimiter ";" -f "...path-to-my-file...\newusers.csv"
```

Using the [Storage Explorer](https://azure.microsoft.com/en-us/features/storage-explorer/) you can view a Table Storage table named `users` and see that you have created the users. 

![StorageExplorer](/media/StorageExplorer.png)

## Edit and upload the B2C Custom Policies

You'll find the template B2C policies in [this github repo](https://github.com/azure-ad-b2c/samples/tree/master/policies/signin-migration/b2c/policy). You also need to copy the [TrustFrameworkBase.xml](https://github.com/Azure-Samples/active-directory-b2c-custom-policy-starterpack/blob/master/SocialAndLocalAccountsWithMfa/TrustFrameworkBase.xml) file from the Starter Pack.

When you have saved the files to a local folder, then run the following command to change the settings to match your tenant.

```powershell
Set-AzADB2CPolicyDetail
```

After that, you need to update the url endpoint to point to your Azure Function so that B2C can do the REST API call to validate the user and password. It is the `ServiceUrl` in the metadata section that needs updating.

```xml
    <ClaimsProvider>
      <DisplayName>REST API to communicate with Legacy IdP</DisplayName>
      <TechnicalProfiles>
        <TechnicalProfile Id="UserMigrationViaLegacyIdp">
          <DisplayName>REST API call to communicate with Legacy IdP</DisplayName>
          <Protocol Name="Proprietary" Handler="Web.TPEngine.Providers.RestfulProvider, Web.TPEngine, Version=1.0.0.0, Culture=neutral, PublicKeyToken=null" />
          <Metadata>
            <Item Key="ServiceUrl">https://<yourazfuncname>.azurewebsites.net/api/TableStorageUser?code=...your code...</Item>
            <Item Key="AuthenticationType">None</Item>
            <Item Key="AllowInsecureAuthInProduction">true</Item>
            <Item Key="SendClaimsIn">Body</Item>
          </Metadata>
```

Change the UserJourney id to something new, like `SignupOrSignin-Migration`

**TrustFrameworkExtensions.xml**
```xml
    <UserJourney Id="SignUpOrSignIn-Migration">
```
**SignupOrSignin.xml**
```xml
  <RelyingParty>
    <DefaultUserJourney ReferenceId="SignUpOrSignIn-Migration" />
```

Then it is time to upload the policies to your B2C tenant
```powershell
Import-AzADB2CPolicyToTenant
```

## Testing the Seamless migration

You can now test the B2C policy that contains the Seamless Password Migration flow by running the policy.
 
```powershell
Test-AzADB2CPolicy -n "ABC-WebApp" -p .\SignupOrSignin.xml
```

Try to sign in with `alice@contoso.com` and the password you specified in the CSV file.

![TestMigration1](/media/TestMigration1.png)

If you at the same time have the Log window open in the Azure Function, you will see the trace message for when B2C makes the REST API can

![TestMigration2](/media/TestMigration2.png)

You can then verify that the `requiresMigration` extension attribute has been flipped to `False` after the signin via running the following powershell command.

```powershell
$resp = Invoke-RestMethod -Uri "https://graph.microsoft.com/beta/users?$filter=givenname eq 'alice" -Headers $global:authHeader -Method "GET" -ContentType "application/json"
$resp.value
```

With this, you have completed the Seamless Migration exersice!
