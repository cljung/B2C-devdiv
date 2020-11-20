# Group Membership in B2C token

This sample can be used to get a `groups` claim in the id/access token. The way it works is

- B2C makes a REST API call to an Azure Function
- The Azure Function makes a GraphAPI call to pull up the user's group membership

![JWT token with Group claims](/media/jwt-token-with-group-claim.png)

## B2C Powershell Module - Install
Quickly run through the [1-begin](./1-begin) lab to make sure you have configured the B2C Identity Experience Framework.

## To Deploy the Azure Function

- Create an [Azure Function App](https://ms.portal.azure.com/#create/Microsoft.FunctionApp) with runtime `.NET Core` and create a new Function of type `HTTPTrigger`. Choose OS=Windows and Plan type=Consumption.
- Open the code editor in the portal and paste over the code from [run.csx](./source-code/run.csx)
- Save the code
- Add to Configuration App Settings with the key name of `B2C_{guid}_ClientId` and `B2C_{guid}_ClientSecret` where the `{guid}` part is the guid of your B2C tenant. The value of the respective config settings is an App Reg in your B2C tenant with permission of `User.Read.All` for Microsoft Graph API.

In a real deployment you probably would create a separate App Registration with the appropriate Graph API permissions for the Azure Functions, but if you just want to get this sample running - and are using the powershell module - you can use the `B2C-Grap-App` id and secret. You'll find the values if you type `$env:B2CAppID` and `$env:B2CAppKey` in your powershell session command prompt. 

### Create an Azure Function App

![Create an Azure Function App](/media/CreateFunctionApp.png)

## To Deploy the B2C Custom Policy

The sample [TrustFrameworkExtensions.xml](./policies/TrustFrameworkExtensions.xml) contains the changes you need to to do to get a working solution.

The changes in you solutions file `TrustFrameworkExtensions.xml` are these:

You need a claims type definition for storing the group collection. This change goes inside the `<BuidlingBlocks>` element in your `TrustFrameworkExtensions.xml`.

```xml
    <ClaimsSchema>
      <ClaimType Id="groups">
        <DisplayName>Comma delimited list of group names</DisplayName>
        <DataType>stringCollection</DataType>
        <UserInputType>Readonly</UserInputType>
      </ClaimType>
    </ClaimsSchema>
```

You then need to add a claims provider to call the Azure Function. This change goes inside the `<ClaimsProviders>` element in your `TrustFrameworkExtensions.xml`. Update the following
- ServiceUrl
- tenantId <InputClaim>

```xml
    <ClaimsProvider>
      <DisplayName>Group Membership</DisplayName>
      <TechnicalProfiles>
        <TechnicalProfile Id="GetUserGroups">
          <DisplayName>Retrieves security groups assigned to the user</DisplayName>
          <Protocol Name="Proprietary" Handler="Web.TPEngine.Providers.RestfulProvider, Web.TPEngine, Version=1.0.0.0, Culture=neutral, PublicKeyToken=null" />
          <Metadata>
            <Item Key="ServiceUrl">https://your-azfunc.azurewebsites.net/api/GetGroupMembershipMSGraph?code=...</Item>
            <Item Key="AuthenticationType">None</Item>
            <Item Key="SendClaimsIn">Body</Item>
            <Item Key="AllowInsecureAuthInProduction">false</Item>
          </Metadata>
          <InputClaims>
            <InputClaim Required="true" ClaimTypeReferenceId="objectId" />
            <InputClaim ClaimTypeReferenceId="tenantId" DefaultValue="...your tenandid guid ..."/>
          </InputClaims>
          <OutputClaims>
            <OutputClaim ClaimTypeReferenceId="groups" />
          </OutputClaims>
          <UseTechnicalProfileForSessionManagement ReferenceId="SM-Noop" />
        </TechnicalProfile>
      </TechnicalProfiles>
    </ClaimsProvider>
```

The last change in your `TrustFrameworkExtensions.xml` file is to modify your user journey to actually call the REST API. This may be done in many separate ways, but the way this sample does it is to create a brand new journey that only works for Local Accounts and then get's the group memberships. You may include it differently in your user journey.

```xml
<UserJourneys>
    <UserJourney Id="SignUpOrSignIn-Grp">
      <OrchestrationSteps>
        <OrchestrationStep Order="1" Type="CombinedSignInAndSignUp" ContentDefinitionReferenceId="api.signuporsignin">
          <ClaimsProviderSelections>
            <ClaimsProviderSelection ValidationClaimsExchangeId="LocalAccountSigninEmailExchange" />
          </ClaimsProviderSelections>
          <ClaimsExchanges>
            <ClaimsExchange Id="LocalAccountSigninEmailExchange" TechnicalProfileReferenceId="SelfAsserted-LocalAccountSignin-Email" />
          </ClaimsExchanges>
        </OrchestrationStep>
        <OrchestrationStep Order="2" Type="ClaimsExchange">
          <Preconditions>
            <Precondition Type="ClaimsExist" ExecuteActionsIf="true">
              <Value>objectId</Value>
              <Action>SkipThisOrchestrationStep</Action>
            </Precondition>
          </Preconditions>
          <ClaimsExchanges>
            <ClaimsExchange Id="SignUpWithLogonEmailExchange" TechnicalProfileReferenceId="LocalAccountSignUpWithLogonEmail" />
          </ClaimsExchanges>
        </OrchestrationStep>
        <OrchestrationStep Order="3" Type="ClaimsExchange">
          <ClaimsExchanges>
            <ClaimsExchange Id="AADUserReadWithObjectId" TechnicalProfileReferenceId="AAD-UserReadUsingObjectId" />
          </ClaimsExchanges>
        </OrchestrationStep>
        <OrchestrationStep Order="4" Type="ClaimsExchange">
          <ClaimsExchanges>
            <ClaimsExchange Id="GetUserGroups" TechnicalProfileReferenceId="GetUserGroups" />
          </ClaimsExchanges>
        </OrchestrationStep>        
        <OrchestrationStep Order="5" Type="SendClaims" CpimIssuerTechnicalProfileReferenceId="JwtIssuer" />    
      </OrchestrationSteps>
      <ClientDefinition ReferenceId="DefaultWeb" />
    </UserJourney>
</UserJourneys>
```

Then you need to update your Relaying Party file which in this sample is [SignUpOrSignin.xml](./policies/SignUpOrSignin.xml). It needs to return the `groupds` claim.

```xml
        <OutputClaim ClaimTypeReferenceId="groups" />
```

Also, make sure the new DefaultUserJourney is referenced in the file SignupOrSignin.xml

```xml
    <!--<DefaultUserJourney ReferenceId="SignUpOrSignIn" />-->
    <DefaultUserJourney ReferenceId="SignUpOrSignIn-Grp" />
```

## Testing

Open the `Azure Active Directory` blade in portal.azure.com for the B2C tenant, goto `groups` and add a B2C user as a member of the group. Signin in with this user should produce a token including the `groups`. 