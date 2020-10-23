# B2C UX Customization

This sample can be used to get a `groups` claim in the id/access token. The way it works is

- B2C makes a REST API call to an Azure Function
- The Azure Function makes a GraphAPI call to pull up the user's group membership

## B2C UX Customization

This part shows you how you can modify UxElements via changes in the B2C policy files. This includes things like standard paragraph headers, etc, that B2C presents that you may wish to modify/override.

## Override ContentDefinitions

In order to make modifications to the standard UX, you need to override the `ContentDefinition` of the page you want to modify. In our case we will add a `LocalizedResourcesReferences` element to the `api.signuporsignin` page definition. This definition means we open up the ability to make changes to the UX. 

```xml
    <ContentDefinitions>
      <ContentDefinition Id="api.signuporsignin">
        <LoadUri>~/tenant/templates/AzureBlue/unified.cshtml</LoadUri>
        <RecoveryUri>~/common/default_page_error.html</RecoveryUri>
        <DataUri>urn:com:microsoft:aad:b2c:elements:contract:unifiedssp:2.1.0</DataUri>
        <Metadata>
          <Item Key="DisplayName">Signin and Signup</Item>
        </Metadata>
        <!-- added -->
        <LocalizedResourcesReferences MergeBehavior="Prepend">
            <LocalizedResourcesReference Language="en" LocalizedResourcesReferenceId="api.signuporsignin.en" />
        </LocalizedResourcesReferences>      
        <!-- added -->
      </ContentDefinition>
    </ContentDefinitions>
```

So, futher down in the `<BuildingBlocks>` element you add the following. It will change some `UxElement` textuals of your B2C UX. 
 
```xml
    <Localization Enabled="true">
      <SupportedLanguages DefaultLanguage="en" MergeBehavior="ReplaceAll">
        <SupportedLanguage>en</SupportedLanguage>
      </SupportedLanguages>
      <LocalizedResources Id="api.signuporsignin.en">
        <LocalizedStrings>
          <LocalizedString ElementType="UxElement" StringId="social_intro">Federated Identity Providers</LocalizedString>
          <LocalizedString ElementType="UxElement" StringId="button_signin">Login</LocalizedString>
          <LocalizedString ElementType="UxElement" StringId="createaccount_intro">Need an account?</LocalizedString>
        </LocalizedStrings>
      </LocalizedResources>
    </Localization>    
```

If you want to customize more `UxElement`, you will find the `StringId` names in this documentation page: [Localization string IDs](https://docs.microsoft.com/en-us/azure/active-directory-b2c/localization-string-ids)