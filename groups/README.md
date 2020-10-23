# Group Membership in B2C token

This sample can be used to get a `groups` claim in the id/access token. The way it works is

- B2C makes a REST API call to an Azure Function
- The Azure Function makes a GraphAPI call to pull up the user's group membership

## To Deploy the Azure Function

- Create an Azure Function App with runtime `.NET Core` and create a new Function of type `HTTPTrigger`
- Open the code editor in the portal and paste over the code from [run.csx](./source-code/run-csx)
- Save the code
- Add to Configuration App Settings with the key name of `B2C_{guid}_ClientId` and `B2C_{guid}_ClientSecret` where the `{guid}` part is the guid of your B2C tenant. The value of the respective config settings is an App Reg in your B2C tenant with permission of `User.Read.All` for Microsoft Graph API.

## To Deploy the B2C Custom Policy

The sample [TrustFrameworkExtensions.xml](.\policies\TrustFrameworkExtensions.xml) contains the changes you need to to do to get a working solution.

The changes in you solutions file `TrustFrameworkExtensions.xml` are these:

You need a claims type definition for storing the group collection

```xml
    <ClaimsSchema>
      <ClaimType Id="groups">
        <DisplayName>Comma delimited list of group names</DisplayName>
        <DataType>stringCollection</DataType>
        <UserInputType>Readonly</UserInputType>
      </ClaimType>
    </ClaimsSchema>
```

You then need to add a claims provider to call the Azure Function. Update the following
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

Then you need to update your Relaying Party file which in this sample is [SignUpOrSignin.xml](.\policies\SignUpOrSignin.xml). It needs to return the `groupds` claim.

```xml
        <OutputClaim ClaimTypeReferenceId="groups" />
```

## Testing

Open the `Azure Active Directory` blade in portal.azure.com for the B2C tenant, goto `groups` and add a B2C user as a member of the group. Signin in with this user should produce a token including the `groups`. 