# First change to your B2C Custom Policy

After you have completed step [1-begin](/1-begin), it is time to modify your custom policy. This example shows you how to add KMSI (Keep-me-signed-in) and how to sign in with a username or a loyality number.

## KMSI
KMSI is about setting and expiry date on the SSO cookie, named x-ms-cpim-sso:yourtenant, so that it is not deleted when you close your browser session.

Details for editing your B2C Policy to add KMSI is in the documentation [here](https://docs.microsoft.com/en-us/azure/active-directory-b2c/custom-policy-keep-me-signed-in). The part about the `Configure the page identifier` is already taken care of by the powershell command in step [1-begin](/1-begin), so you can start with the part of adding metadata to the Technical Profile. The short snipet of code you ad to TrustFrameworkExtensions.xml will add a metadata setting to enable the KMSI checkbox. The complete configuration for the Technical Profile `SelfAsserted-LocalAccountSignin-Email` is found in TrustFrameworkBase.xml.

The part you add to SignupOrSignin.xml is to define how log the SSO cookie should live. You will already have a `<UserJourneyBehaviours>` element, so make sure you add the three new lines before the existing lines you have in that file.

After you have made the changes described in the above documentation page, your files should contain thís:

### TrustFrameworkExtensions.xml
```xml
<ClaimsProvider>
  <DisplayName>Local Account</DisplayName>
  <TechnicalProfiles>
    <TechnicalProfile Id="SelfAsserted-LocalAccountSignin-Email">
      <Metadata>
        <Item Key="setting.enableRememberMe">True</Item>
      </Metadata>
    </TechnicalProfile>
  </TechnicalProfiles>
</ClaimsProvider>
```

### SigninOrSignup.xml
```xml
    <UserJourneyBehaviors>
      <SingleSignOn Scope="Tenant" KeepAliveInDays="30" />
      <SessionExpiryType>Absolute</SessionExpiryType>
      <SessionExpiryInSeconds>1200</SessionExpiryInSeconds>
      <JourneyInsights TelemetryEngine="ApplicationInsights" InstrumentationKey="...your key..." DeveloperMode="true" ClientEnabled="true" ServerEnabled="true" TelemetryVersion="1.0.0" />
      <ScriptExecution>Allow</ScriptExecution>
    </UserJourneyBehaviors>
```

Remember not to test KMSI with an inprivate/incognito browser as the cookies will be lost when you close the browser. 

## Sign in with Username or LoyalityNumber

The TrustFrameworkBase.xml defines a setting named `setting.operatingMode` set to email. This is the setting that forces the signing name to evaluate to an email address. In your TrustFrameworkExtensions.xml file, add the below line that changes this setting to `<Item Key="setting.operatingMode">username</Item>`. This will enable the input textbox in the UX to allow anything and not just an email.

```xml
<ClaimsProvider>
  <DisplayName>Local Account</DisplayName>
  <TechnicalProfiles>
    <TechnicalProfile Id="SelfAsserted-LocalAccountSignin-Email">
      <Metadata>
        <Item Key="setting.enableRememberMe">True</Item>
        <Item Key="setting.operatingMode">username</Item> <!-- add this line -->
      </Metadata>
    </TechnicalProfile>
  </TechnicalProfiles>
</ClaimsProvider>
```

## Save, upload and test the policy

Run the powershell command to upload the modified policies.

```powershell
Deploy-AzureADB2CPolicyToTenant
```

Once the policies are uploaded, you can use the Test command to launch a browser to run an authorize flow. It will start the default browser on your laptop. If you want to start a different browser you pass the `-Firefox`, `-Edge` or `-Chrome` argument. 

```powershell
Test-AzureADB2CPolicy -n "ABC-WebApp" -p .\SignUpOrSignin.xml
```

## Add a username and Loyality Number to your B2C user

You need to modify your user in B2C to have information about the username and loyality number. For this, we need to launch Microsoft Graph Explorer [https://developer.microsoft.com/en-us/graph/graph-explorer](https://developer.microsoft.com/en-us/graph/graph-explorer). In step [1-begin](/1-begin) you created a Local Admin user named `graphexplorer` (or whatever you named it). Sign in to Microsoft Graph Explorer using this account `graphexplorer@yourtenant.onmicrosoft.com`. Even though this user is Global Administrator of the tenant, you need to Consent to the permissions you will use in the `Modify permissions` tab.

### First, find your user

Run this query and then search (Ctrl+F) for your user. 

```http
https://graph.microsoft.com/v1.0/users/?$select=id,displayName,identities
```

Copy the id guid and modify the url and rerun the query.

```http
https://graph.microsoft.com/v1.0/users/<guid>/?$select=id,displayName,identities
```

### Make changes to the identities collection

Then copy the entire `identities` JSON section and paste it into VSCode and edit it into something like this

```json
"identities": [
    {
        "signInType": "emailAddress",
        "issuer": "yourtenant.onmicrosoft.com",
        "issuerAssignedId": "alice@contoso.com"
    },
    {
        "signInType": "userName",
        "issuer": "yourtenant.onmicrosoft.com",
        "issuerAssignedId": "...your prefered username..."
    },
    {
        "signInType": "LoyalityNumber",
        "issuer": "yourtenant.onmicrosoft.com",
        "issuerAssignedId": "...your prefered loyality number..."
    },
    {
        "signInType": "userPrincipalName",
        "issuer": "yourtenant.onmicrosoft.com",
        "issuerAssignedId": "...guid...@yourtenant.onmicrosoft.com"
    }
]
```

### Update the user object

Paste the edited JSON to Microsoft Graph Explorer's `Request Body` input area, change method to PATCH and the url to the below and Run the query

```http
https://graph.microsoft.com/v1.0/users/<guid>
```
 
Finally, change the method back to GET and the url to the below and Run the query to verify your changes.

```http
https://graph.microsoft.com/v1.0/users/<guid>/?$select=id,displayName,identities
```

### Retest your B2C policy

Once the user object is updated, you can now rerun your B2C policy and sign in using a username or loyality number.

```powershell
Test-AzureADB2CPolicy -n "ABC-WebApp" -p .\SignUpOrSignin.xml
```
