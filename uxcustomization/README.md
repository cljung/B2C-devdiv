# B2C UX Customization

This sample can be used to get a `groups` claim in the id/access token. The way it works is

- B2C makes a REST API call to an Azure Function
- The Azure Function makes a GraphAPI call to pull up the user's group membership

## B2C UX Customization

This part shows you how you can modify UxElements via changes in the B2C policy files. This includes things like standard paragraph headers, etc, that B2C presents that you may wish to modify/override.

## Override standard B2C UX via ContentDefinitions

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

## Override UX in the Browser

So, if you want to modify the B2C UX more that the `UXElements` it produces, you need to revert to custom html/css and javascript. In order to make B2C load your custom html, you need to create it, store it and make it available publically. One way of making your custom html publically available is using [Azure Blob Storage](https://docs.microsoft.com/en-us/azure/active-directory-b2c/custom-policy-ui-customization#2-create-an-azure-blob-storage-account). This is not something you should do for production, but it works in development.

So, to use your own html, you can download a copy of the default html template `https://yourtenant.b2clogin.com/static/tenant/templates/AzureBlue/unified.cshtml` (which you can do via File Open in VS Code) and save it as your own. After you edit it, you then upload it to your Azure Storage account as mentioned above in the microsoft docs link.

Then, you modify the `<ContentDefinition>` element you created above to be like this.

```xml
      <ContentDefinition Id="api.signuporsignin">
        <!--<LoadUri>~/tenant/templates/AzureBlue/unified.cshtml</LoadUri>-->
        <LoadUri>https://yourstorageaccount.blob.core.windows.net/yourcontainer/unified.html</LoadUri>
        <RecoveryUri>~/common/default_page_error.html</RecoveryUri>
        <DataUri>urn:com:microsoft:aad:b2c:elements:contract:unifiedssp:2.1.0</DataUri>
        <Metadata>
          <Item Key="DisplayName">Signin and Signup</Item>
        </Metadata>
      </ContentDefinition>
```

In that `unified.html` file, you then should add the following. This will modify the UX in the following ways:
- The `Password` and the `Forgot Password` link will be hidden on page load
- A `Continue` button will be shown
- The `Password` and the `Forgot Password` link will be displayed when the `Continue` button is pressed
- The Social Providers will be hidden when the `Continue` button is pressed
- The AzureAD federation will auto-complete if (you have a ClaimsProvider for it) and you enter an acccount like `meganb@whatever.onmicrosoft.com`

```html
</body>
<script>

function showHidePasswordElements(displayStyle) {
    document.getElementById("next").style.display = displayStyle;
    document.getElementById("password").style.display = displayStyle;
    document.getElementById("forgotPassword").style.display = displayStyle;
}

var buttons = document.getElementsByClassName("buttons")[0];
buttons.innerHTML = buttons.innerjavascriptHTML + "<button id=\"idContinue\" onclick=\"continueLogin()\">Continue</button>";
showHidePasswordElements("none");

var re = /^(([^<>()\[\]\\.,;:\s@"]+(\.[^<>()\[\]\\.,;:\s@"]+)*)|(".+"))@((\[[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\])|(([a-zA-Z\-0-9]+\.)+[a-zA-Z]{2,}))$/;

document.getElementById("signInName").addEventListener("keyup", autoRedirectToClaimsProvider);
function autoRedirectToClaimsProvider(e) {
    if ( re.test(String( document.getElementById("signInName").value.toLowerCase() ) ) ) {
        if (document.getElementById("signInName").value.endsWith(".onmicrosoft.com") ) {
            document.getElementById("ContosoExchange").click();
        }
    }  
}    

function continueLogin() {
    if ( re.test(String( document.getElementById("signInName").value.toLowerCase() ) ) ) {
        document.getElementById("idContinue").style.display = "none";
        showHidePasswordElements("inline-block");
        document.getElementsByClassName("claims-provider-list-buttons")[0].style.display = "none";
    }  
}
</script>
</html>
``` 

You need to edit the Relying Party file `SignUpOrSignin.xml` to make it allow javascript. You do that by adding

```xml
  <RelyingParty>
    <DefaultUserJourney ReferenceId="SignUpOrSignIn" />
    <UserJourneyBehaviors>
      <ScriptExecution>Allow</ScriptExecution>
    </UserJourneyBehaviors>
    <TechnicalProfile Id="PolicyProfile">
```
