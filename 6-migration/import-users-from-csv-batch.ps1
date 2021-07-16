param (
    [Parameter(Mandatory=$False)][Alias('t')][string]$Tenant = "",
    [Parameter(Mandatory=$True)][Alias('f')][string]$Path = ".\users.csv",
    [Parameter(Mandatory=$False)][Alias('d')][string]$Delimiter = ";", # the delimiter used in file 
    [Parameter(Mandatory=$False)][Alias('c')][string]$client_id = "", # the Client ID used to register the attribute
    [Parameter(Mandatory=$false)][switch]$ImportPassword = $False,
    [Parameter(Mandatory=$False)][Alias('a')][string]$access_token = "",
    [Parameter(Mandatory=$False)][Alias('b')][int]$batch_size = 10
    )

if ( 0 -eq $access_token.length ) {
    write-error "No access_token on command line"
    return
}
<# #>
# if no appObjectId given, use the standard b2c-extensions-app
if ( "" -eq $client_id ) {
    $appExt = Get-AzureADApplication -SearchString "b2c-extensions-app"
} else {
    $appExt = Get-AzureADApplication -Filter "AppID eq '$client_id'"
}

$client_id = $appExt.AppId   
$extId = $client_id.Replace("-", "") # the name is w/o hyphens
$requiresMigrationAttributeName = "extension_$($extId)_requiresMigration"
$phoneNumberVerifiedAttributeName = "extension_$($extId)_phoneNumberVerified"

$extAttrs = get-AzureADApplicationExtensionProperty -ObjectId $appExt.ObjectId
if ( $null -eq ($extAttrs | where {$_.Name -eq $requiresMigrationAttributeName })) {
    write-error "Extension Attribute not registered: $requiresMigrationAttributeName"
    return
} 
if ( $null -eq ($extAttrs | where {$_.Name -eq $phoneNumberVerifiedAttributeName })) {
    write-error "Extension Attribute not registered: $phoneNumberVerifiedAttributeName"
    return
} 
<# #>#>
$tmpPwd = "Aa$([guid]::NewGuid())!"
$countImported = 0

function BatchCreateB2CUsers( $body ) {
    $authHeader = @{"Authorization"= "Bearer $access_token";"Content-Type"="application/json";"ContentLength"=$body.length }
    $url = "https://graph.microsoft.com/v1.0/`$batch"
    try {
        $resp = Invoke-WebRequest -Headers $authHeader -Uri $url -Method Post -Body $body    
        foreach( $resp in ($resp.Content | ConvertFrom-json).responses) { 
            if ( $resp.status -eq "201" ) {
                $countImported++
                write-host -BackgroundColor Black -ForegroundColor Green "id: " $resp.id " " $resp.body.id " " $resp.body.displayName
            } else {
                write-host -BackgroundColor Black -ForegroundColor Red -NoNewLine "id: " $resp.id " StatusCode: " $resp.status " Error: " $resp.body.error.message
            }
        }
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
}

function FormatB2CUserRecord( $usr ) {
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
return $body
}


$csv = import-csv -path $path -Delimiter $Delimiter

$startTime = Get-Date

$payload = ""
$count = 0
$reqId = 0
$sep = ""

foreach( $usr in $csv ) {
    if ( $reqId -eq 0 ) {
    $payload = @"
{
    "requests": [
"@
    }
    $body = FormatB2CUserRecord $usr
    $count++
    $reqid++
    $req = @"
    {
        "id": "$reqId",
        "method": "POST",
        "url": "/users",
        "headers": {
            "Content-Type": "application/json"
        },
        "body":
        $body
    }
"@
    $payload += $sep + $req
    if ( $reqId -ge $batch_size ) {
        $payload += "]}"     
        #write-output "*** BATCH ***"   
        #write-output $payload
        BatchCreateB2CUsers $payload
        $reqId = 0        
        $sep = ""
    } else {
        $sep = ",`n"
    }
}
if ( $reqId -gt 0 ) {
    $payload += "]}"
    BatchCreateB2CUsers $payload
}
write-output "Imported $countImported/$count users"

$finishTime = Get-Date
$TotalTime = ($finishTime - $startTime).TotalSeconds
Write-Output "Time: $TotalTime sec(s)"