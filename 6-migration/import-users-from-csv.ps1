param (
    [Parameter(Mandatory=$False)][Alias('t')][string]$Tenant = "",
    [Parameter(Mandatory=$True)][Alias('f')][string]$Path = ".\users.csv",
    [Parameter(Mandatory=$False)][Alias('d')][string]$Delimiter = ";", # the delimiter used in file 
    [Parameter(Mandatory=$False)][Alias('c')][string]$client_id = "", # the Client ID used to register the attribute
    [Parameter(Mandatory=$false)][switch]$ImportPassword = $False,
    [Parameter(Mandatory=$False)][Alias('a')][string]$access_token = ""
    )

if ( 0 -eq $access_token.length ) {
    write-error "No access_token on command line"
    return
}

# if no appObjectId given, use the standard b2c-extensions-app
if ( "" -eq $client_id ) {
    $appExt = Get-AzADApplication -DisplayNameStartWith "b2c-extensions-app"
} else {
    [GUID]$appid = $client_id
    $appExt = Get-AzADApplication -ApplicationId $appid
}

$client_id = $appExt.AppId   
$extId = $client_id.Replace("-", "") # the name is w/o hyphens
$requiresMigrationAttributeName = "extension_$($extId)_requiresMigration"
$phoneNumberVerifiedAttributeName = "extension_$($extId)_phoneNumberVerified"

$tmpPwd = "Aa$([guid]::NewGuid())!"

function CreateUserInB2C( $usr ) {
    $pwd = $tmpPwd
    $requiresMigrationAttribute = "true"
    $passwordPolicies = "`"passwordPolicies`": `"DisablePasswordExpiration`","
    # if we DO have the password in the CSV file, we are good to go and need no further migration
    if ( $True -eq $ImportPassword -and $usr.password.Length -gt 0 ) {
        $pwd = $usr.password
        $requiresMigrationAttribute = "false"
        $passwordPolicies = "`"passwordPolicies`": `"DisablePasswordExpiration,DisableStrongPassword`","
    }

    $mobileLine = ""
    if ( "" -ne $usr.mobile ) {
        $mobileLine = "`"mobilePhone`": `"$($usr.mobile)`","
    }
    $enabled=$usr.accountEnabled.ToLower()

    # see https://docs.microsoft.com/en-us/graph/api/resources/user?view=graph-rest-1.0
    $body = @"
        {
          "accountEnabled": $enabled,
          "creationType": "LocalAccount",
          "displayName": "$($usr.displayName)",
          "surname": "$($usr.surname)",
          "givenname": "$($usr.givenname)",
          $mobileLine
          $passwordPolicies
          "passwordProfile": {
            "password": "$pwd",
            "forceChangePasswordNextSignIn": false
          },
          "identities": [
            {
                "signInType": "userName",
                "issuer": "$tenant",
                "issuerAssignedId": "$($usr.userName)"
            },  
            {
              "signInType": "emailAddress",
              "issuer": "$tenant",
              "issuerAssignedId": "$($usr.emailAddress)"
            }
          ],
          "$requiresMigrationAttributeName": $requiresMigrationAttribute,
          "$phoneNumberVerifiedAttributeName": $($usr.phoneNumberVerified)
        }
"@

    write-host "Creating user: $($usr.userName) / $($usr.emailAddress)"
    #write-host $body
    <##>
    $authHeader = @{"Authorization"= "Bearer $access_token";"Content-Type"="application/json";"ContentLength"=$body.length }
    $url = "https://graph.microsoft.com/v1.0/$tenant/users"
    try {
        $newUser = Invoke-WebRequest -Headers $authHeader -Uri $url -Method Post -Body $body    
        $userObjectID = ($newUser.Content | ConvertFrom-json).objectId
        write-host -BackgroundColor Black -ForegroundColor Green "$($usr.emailAddress)"
        #write-host $newUser
        #write-host $newUser.Content
        $countCreated += 1
    } catch {
        $exception = $_.Exception
        write-host -BackgroundColor Black -ForegroundColor Red -NoNewLine "StatusCode: " $exception.Response.StatusCode.value__ " "
        $streamReader = [System.IO.StreamReader]::new($exception.Response.GetResponseStream())
        $streamReader.BaseStream.Position = 0
        $streamReader.DiscardBufferedData()
        $errBody = $streamReader.ReadToEnd()
        $streamReader.Close()
        write-host -BackgroundColor Black -ForegroundColor Red "Error: " $errBody    
    }
    <##>
}


$csv = import-csv -path $path -Delimiter $Delimiter

$startTime = Get-Date

$count = 0
foreach( $usr in $csv ) {
    CreateUserInB2C $usr
    $count += 1
}
write-output "Imported $count users"
$finishTime = Get-Date
$TotalTime = ($finishTime - $startTime).TotalSeconds
Write-Output "Time: $TotalTime sec(s)"
