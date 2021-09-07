# Exporting / Importing users in Azure AD B2C

If you need to export users from an Azure AD B2C tenant and import it to another tenant, here are some example scripts to show you how it can be done.

There is an accompanying blog post that explains the export/import concept [here](http://www.redbaronofazure.com/?p=7804)
## Authentication
These samples work with `client_credentials` authentication, meaning, you need to register an Azure AD B2C application and grant in application permission for `User.ReadWrite.All`, `Group.ReadWrite.All` and `Application.ReadWrite.All` in the target system. In the source tenant it needs to have similar read permissions, like `User.Read.All`, `Group.Read.All` and `Application.Read.All` since we're not updating anything in the source tenant.

Before running the export and import scripts, you need to do the following in the respective powershell command prompts (please use seperate ones)

```powershell
$tenantName = "yourtenanr.onmicrosoft.com"
$AppId = "...guid..."
$AppKey = "...data..."
$oauthBody  = @{grant_type="client_credentials";client_id=$AppID;client_secret=$AppKey;scope="https://graph.microsoft.com/.default offline_access"}
$oauth      = Invoke-RestMethod -Method Post -Uri "https://login.microsoftonline.com/$tenantName/oauth2/v2.0/token" -Body $oauthBody
$authHeader =@{ 'Content-Type'='application/json'; 'Authorization'=$oauth.token_type + ' ' + $oauth.access_token }
```
