function Connect-GraphDevicelogin {
    [cmdletbinding()]
    param( 
        [Parameter()][Alias('c')]$ClientID = '1950a258-227b-4e31-a9cf-717495945fc2',        
        [Parameter()][Alias('t')]$TenantName = 'common',        
        [Parameter()][Alias('r')]$Resource = "https://graph.microsoft.com/",        
        [Parameter()][Alias('s')]$Scope = "",        
        # Timeout in seconds to wait for user to complete sign in process
        [Parameter(DontShow)]$Timeout = 300,
        [Parameter(Mandatory=$false)][switch]$Chrome = $False,
        [Parameter(Mandatory=$false)][switch]$Edge = $False,
        [Parameter(Mandatory=$false)][switch]$Firefox = $False,
        [Parameter(Mandatory=$false)][switch]$Incognito = $True,
        [Parameter(Mandatory=$false)][switch]$NewWindow = $True
    )

    Function IIf($If, $Right, $Wrong) {If ($If) {$Right} Else {$Wrong}}
    
    if ( !($Scope -imatch "offline_access") ) { $Scope += " offline_access"} # make sure we get a refresh token
    $retVal = $null
    $url = "https://microsoft.com/devicelogin"
    $isMacOS = ($env:PATH -imatch "/usr/bin" )
    $pgm = "chrome.exe"
    $params = "--incognito --new-window"
    if ( !$IsMacOS ) {
        $Browser = ""
        if ( $Chrome ) { $Browser = "Chrome" }
        if ( $Edge ) { $Browser = "Edge" }
        if ( $Firefox ) { $Browser = "Firefox" }
        if ( $browser -eq "") {
            $browser = (Get-ItemProperty HKCU:\Software\Microsoft\windows\Shell\Associations\UrlAssociations\http\UserChoice).ProgId
        }
        $browser = $browser.Replace("HTML", "").Replace("URL", "")
        switch( $browser.ToLower() ) {        
            "firefox" { 
                $pgm = "$env:ProgramFiles\Mozilla Firefox\firefox.exe"
                $params = (&{If($Incognito) {"-private "} Else {""}}) + (&{If($NewWindow) {"-new-window"} Else {""}})
            } 
            "chrome" { 
                $pgm = "chrome.exe"
                $params = (&{If($Incognito) {"--incognito "} Else {""}}) + (&{If($NewWindow) {"--new-window"} Else {""}})
            } 
            default { 
                $pgm = "msedge.exe"
                $params = (&{If($Incognito) {"-InPrivate "} Else {""}}) + (&{If($NewWindow) {"-new-window"} Else {""}})
            } 
        }  
    }

    try {
        $DeviceCodeRequestParams = @{
            Method = 'POST'
            Uri    = "https://login.microsoftonline.com/$TenantName/oauth2/devicecode"
            Body   = @{
                resource  = $Resource
                client_id = $ClientId
                scope = $Scope
            }
        }
        $DeviceCodeRequest = Invoke-RestMethod @DeviceCodeRequestParams
        #write-host $DeviceCodeRequest
        Write-Host $DeviceCodeRequest.message -ForegroundColor Yellow
        $url = $DeviceCodeRequest.verification_url

        Set-Clipboard -Value $DeviceCodeRequest.user_code

        if ( $isMacOS ) {
            $ret = [System.Diagnostics.Process]::Start("/usr/bin/open","$url")
        } else {
            $ret = [System.Diagnostics.Process]::Start($pgm,"$params $url")
        }

        $TokenRequestParams = @{
            Method = 'POST'
            Uri    = "https://login.microsoftonline.com/$TenantName/oauth2/token"
            Body   = @{
                grant_type = "urn:ietf:params:oauth:grant-type:device_code"
                code       = $DeviceCodeRequest.device_code
                client_id  = $ClientId
            }
        }
        $TimeoutTimer = [System.Diagnostics.Stopwatch]::StartNew()
        while ([string]::IsNullOrEmpty($TokenRequest.access_token)) {
            if ($TimeoutTimer.Elapsed.TotalSeconds -gt $Timeout) {
                throw 'Login timed out, please try again.'
            }
            $TokenRequest = try {
                Invoke-RestMethod @TokenRequestParams -ErrorAction Stop
            }
            catch {
                $Message = $_.ErrorDetails.Message | ConvertFrom-Json
                if ($Message.error -ne "authorization_pending") {
                    throw
                }
            }
            Start-Sleep -Seconds 1
        }
        $retVal = $TokenRequest
        #Write-Output $TokenRequest.access_token
    }
    finally {
        try {
            $TimeoutTimer.Stop()
        }
        catch {
            # We don't care about errors here
        }
    }
    $global:ClientID = $ClientID 
    $global:TenantName = $TenantName 
    $global:tokens = $retval
    $global:authHeader =@{ 'Content-Type'='application/json'; 'Authorization'=$retval.token_type + ' ' + $retval.access_token }
    return $retVal
}

function Refresh-GraphAccessToken {
    [cmdletbinding()]
    param( 
        [Parameter(Mandatory=$false)][Alias('c')]$ClientID = '1950a258-227b-4e31-a9cf-717495945fc2',        
        [Parameter(Mandatory=$false)][Alias('t')]$TenantName = $null,
        [Parameter(Mandatory=$false)][Alias('r')]$refresh_token = $null
    )

    if ( $null -eq $TenantName ) {
        $TenantName = $global:TenantName
    }
    if ( $null -eq $ClientID ) {
        $ClientID = $global:ClientID
    }
    if ( $null -eq $refresh_token ) {
        $refresh_token = $global:tokens.refresh_token
    }
    $refreshTokenParams = @{ 
        grant_type = "refresh_token"
        client_id = "$ClientID"
        refresh_token = $refresh_token
    }
    $retval = Invoke-RestMethod -Method POST -Uri "https://login.microsoftonline.com/$TenantName/oauth2/token" -Body $refreshTokenParams
    $global:tokens = $retval
    $global:authHeader =@{ 'Content-Type'='application/json'; 'Authorization'=$retval.token_type + ' ' + $retval.access_token }

}
# ---------------------------------------------------------------------------------------------------
# some simple wrappers around each type of GraphAPI CRUD call
# ---------------------------------------------------------------------------------------------------

$GraphEndpoint="https://graph.microsoft.com/beta"

function Invoke-GraphRestMethodGet( $path ) {
    write-host "GET $GraphEndpoint/$path"
    return Invoke-RestMethod -Uri "$GraphEndpoint/$path" -Headers $global:authHeader -Method "GET" -ErrorAction Stop
}

function Invoke-GraphRestMethodPost( $path, $body ) {
    write-host "POST $GraphEndpoint/$path`n$body"
    return Invoke-RestMethod -Uri "$GraphEndpoint/$path" -Headers $global:authHeader -Method "POST" -Body $body -ErrorAction Stop
}
function Invoke-GraphRestMethodPatch( $path, $body ) {
    write-host "PATCH $GraphEndpoint/$path`n$body"
    return Invoke-RestMethod -Uri "$GraphEndpoint/$path" -Headers $global:authHeader -Method "PATCH" -Body $body -ErrorAction Stop
}
function Invoke-GraphRestMethodDelete( $path ) {
    write-host "DELETE $GraphEndpoint/$path"
    return Invoke-RestMethod -Uri "$GraphEndpoint/$path" -Headers $global:authHeader -Method "DELETE" -ErrorAction Stop
}

function Get-GraphApp( $appName ) {
    #return Invoke-GraphRestMethodGet "applications?`$filter=startswith(displayName,'$appName')&`$select=id,appId,displayName"
    return Invoke-GraphRestMethodGet "applications?`$filter=startswith(displayName,'$appName')"
}

function Get-GraphServicePrincipal( $appName ) {
    #return Invoke-GraphRestMethodGet "applications?`$filter=startswith(displayName,'$appName')&`$select=id,appId,displayName"
    return Invoke-GraphRestMethodGet "servicePrincipals?`$filter=startswith(displayName,'$appName')"
}
# ---------------------------------------------------------------------------------------------------
# Helper functions to query GraphAPI
# ---------------------------------------------------------------------------------------------------

function New-GraphExtensionAttribute( $name, $app, $dataType ) {
    $body = @"
    {
        "name": "$name",
        "dataType": "$dataType",
        "targetObjects": [ "User"]
    }
"@
    return Invoke-GraphRestMethodPost "applications/$($app.id)/extensionProperties" $body
}
function Get-GraphExtensionAttributes( $app ) {
    return Invoke-GraphRestMethodGet "applications/$($app.id)/extensionProperties"
}

function Remove-GraphExtensionAttribute( $app, $id ) {
    return Invoke-GraphRestMethodDelete "applications/$($app.id)/extensionProperties/$id"
}

<#
  The CreateUser function is a little more complex. 
  - If you don't specify a password, you will need to reset your password and then you will be subject to B2C's password policies
  - If you do specify a password policy here, the password can be weak and anything
  - If you do specify a mobile phone number, set that attribute, otherwise not
#>
function New-GraphUser( 
        [Parameter(Mandatory=$true)][string]$email, 
        [Parameter(Mandatory=$false)][string]$Password, 
        [Parameter(Mandatory=$true)][string]$DisplayName, 
        [Parameter(Mandatory=$false)][string]$Surname, 
        [Parameter(Mandatory=$false)][string]$Givenname, 
        [Parameter(Mandatory=$false)][string]$MobilePhone, 
        [Parameter(Mandatory=$false)][hashtable]$ExtensionAttributes, 
        [Parameter(Mandatory=$false)][switch]$EnablePhoneSignin = $false,
        [Parameter(Mandatory=$false)][switch]$ForceChangePasswordNextSignIn = $false
)
{
    $passwordPolicies = "`"passwordPolicies`": `"DisablePasswordExpiration`","
    # if we DO have the password, we need to add DisableStrongPassword as the current password may be weak
    if ( $password -gt 0 ) {
        $passwordPolicies = "`"passwordPolicies`": `"DisablePasswordExpiration,DisableStrongPassword`","
    }    
    $mobileLine = ""
    $phoneSigninLine = ""
    if ( "" -ne $mobilePhone ) {
        $mobileLine = "`"mobilePhone`": `"$mobilePhone`","
        if ( $EnablePhoneSignin ) {
            $phoneSigninLine = ",`n{ `"signInType`": `"phoneNumber`", `"issuer`": `"$tenantName`", `"issuerAssignedId`": `"$mobilePhone`" }`n"
        }
    } 
    $forcePwdChange = $ForceChangePasswordNextSignIn.ToString().ToLower()
    # add the extra attributes
    $extra = ""
    foreach($key in $extensionAttributes.Keys ) {
        $value = $extensionAttributes[$key]
        $extra += "`"$key`": `"$value`",`n"
    }       
    $body = @"
        {
          "accountEnabled": true,
          "creationType": "LocalAccount",
          "displayName": "$displayName",
          "surname": "$surname",
          "givenname": "$givenname",
          "mail": "$email",
          $mobileLine
          $passwordPolicies
          "passwordProfile": {
            "password": "$password",
            "forceChangePasswordNextSignIn": $forcePwdChange
          },
          $extra
          "identities": [
            {
              "signInType": "emailAddress",
              "issuer": "$tenantName",
              "issuerAssignedId": "$email"
            }$phoneSigninLine
          ]
        }
"@
    return Invoke-GraphRestMethodPost "users" $body
}

function Remove-GraphUser( $userObjectId ) {
    return Invoke-GraphRestMethodDelete "users/$userObjectId"
}

function Set-GraphUserStrongAuthPhoneNumber( $userObjectId, $mobilePhone) {
    $body = @"
        {
            "phoneType": "mobile",
            "phoneNumber": "$mobilePhone"
        }
"@
    return Invoke-GraphRestMethodPost "users/$userObjectId/authentication/phoneMethods" $body
}

function New-GraphGroup( $groupName ) {
    $body = @"
    {    
        "description": "$groupName",
        "displayName": "$groupName",
        "securityEnabled": true,
        "mailEnabled": false,
        "mailNickname": "$groupName"
    }
"@
    return Invoke-GraphRestMethodPost "groups" $body
}

function Remove-GraphGroup( $groupObjectId ) {
    return Invoke-GraphRestMethodDelete "groups/$groupObjectId"
}

function Get-GraphGroup( $groupName ) {
    return Invoke-GraphRestMethodGet "groups?`$filter=startswith(displayName,'$groupName')"
}

function New-GraphGroupMember( $groupObjectId, $userObjectId ) {
    $body = @"
    { 
        "@odata.id": "$GraphEndpoint/directoryObjects/$userObjectId"
    }
"@
    $members = Invoke-GraphRestMethodPost "groups/$groupObjectId/members/`$ref" $body
}

function New-GraphGroupAppRoleAssignment( $groupObjectId, $appRoleId, $servicePrincipalObjectId ) {
    $body = @"
    { 
        "appRoleId":"$appRoleId",
        "principalId":"$groupObjectId",
        "resourceId":"$servicePrincipalObjectId"
    }
"@
    $appRoles = Invoke-GraphRestMethodPost "groups/$groupObjectId/appRoleAssignments" $body
}
function Delete-GraphGroupAppRoleAssignment( $groupObjectId, $appRoleAssignmentId ) {
    # $appRoleAssignmentId = id : R9-jU27ch0mVm6WdlA9es3R9IPKierhDgTE30JOjlQM
    $appRoles = Invoke-GraphRestMethodDelete "groups/$groupObjectId/appRoleAssignments/$appRoleAssignmentId"
}
function Get-GraphGroupAppRoleAssignment( $groupObjectId ) {
    return Invoke-GraphRestMethodGet "groups/$groupObjectId/appRoleAssignments"
}
