import-module .\GraphAPI-Helper.psm1

$tenantName = "yourtenant.onmicrosoft.com" 
$tokens = Connect-GraphDevicelogin -TenantName $tenantName -Scope "Users.ReadWrite.All Groups.ReadWrite.All Applications.ReadWrite.All UserAuthenticationMethod.ReadWrite.All"

# ---------------------------------------------------------------------------------------------------
# Create the extension attributes 
# ---------------------------------------------------------------------------------------------------

# Get b2c-extensions-app - we need it to create extension attributes since AAD extensions have a namespace of an app
$b2cExtensionsApp = (Get-GraphApp "b2c-extensions-app").value

# create extension attributes
$LoyalityNumberAttrName = (New-GraphExtensionAttribute "LoyalityNumber" $b2cExtensionsApp "String").name
$MemberstipStatusAttrName = (New-GraphExtensionAttribute "MembershipStatus" $b2cExtensionsApp "String").name

# ---------------------------------------------------------------------------------------------------
# Create a test user, a grpup (role) and add that user to the role
# ---------------------------------------------------------------------------------------------------

# create a user
[hashtable]$extAttrs = @{$LoyalityNumberAttrName="123456789"; $MemberstipStatusAttrName="Gold"}

$newuser = New-GraphUser -email "cecil@contoso.com" -Password $superSecretPassword `
                        -DisplayName "Cecil Contoso" -Surname "Contoso" -GivenName "Cecil" -MobilePhone "+14255551313" `
                        -ExtensionAttributes $extAttrs `
                        -EnablePhoneSignin

# add phone number that can be used for sending OTP to the phone number
Set-GraphUserStrongAuthPhoneNumber $newuser.id $newuser.mobilePhone

# create a group
$newgroup = New-GraphGroup "SalesAdmin"

# add a user as a member to a group
New-GraphGroupMember $newgroup.id $newuser.id 

# ---------------------------------------------------------------------------------------------------
# for cleaning up. First, delete the group and user in portal.azure.com, then delete the ext attrs
# ---------------------------------------------------------------------------------------------------

Remove-GraphUser $newuser.id

Remove-GraphGroup $newgroup.id

# List and delete our extension attributes
$ret = Get-GraphExtensionAttributes $b2cExtensionsApp

$id = ($ret.value | where {$_.name -eq $LoyalityNumberAttrName }).id
Remove-GraphExtensionAttribute $b2cExtensionsApp $id

$id = ($ret.value | where {$_.name -eq $MemberstipStatusAttrName }).id
Remove-GraphExtensionAttribute $b2cExtensionsApp $id
