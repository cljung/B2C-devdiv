$GraphEndpoint="https://graph.microsoft.com/beta"
$extAttrFile=".\data\ExtensionAttributes.json"
$extAttrFileLookup=".\data\ExtensionAttributesLookup.json"

$eAttrs = ( Get-Content -Path $extAttrFile | ConvertFrom-json)
$eaLookup=@()
foreach( $app in $eAttrs.attributes ) {
    $resp = Invoke-RestMethod -Method GET -Uri "$GraphEndpoint/applications?`$select=id,appId&`$filter=displayName eq '$($app.appName)'" -Headers $authHeader
    $appObjectId = $resp.value.id # need this to POST
    $appIdShort = $resp.value.appId.Replace("-","") # need this as it is part of the attribute name
    $namePrefix = "extension_$appIdShort"    
    $idShort = $app.appId.Replace("-","")
    $nameOld = "extension_$idShort"
    # save for the lookup table
    $eaLookup += @{ name = $nameOld; nameNew = $namePrefix }
    foreach( $extensionAttr in $app.extensionAttributes ) {
        # skip extension attributes that have the name "*_cpiminternal_*" as they are B2C internal
        $name = $extensionAttr.name
        $body = @"
{
    "name": "$name",
    "dataType": "$($extensionAttr.dataType)",
    "targetObjects": [ "User"]
}
"@
        $resp = Invoke-RestMethod -Method "POST" -Uri "$GraphEndpoint/applications/$appObjectId/extensionProperties" -Headers $authHeader -Body $body
    }
}
Set-Content -Path $extAttrFileLookup -Value "{ `"attributes`":`n$($eaLookup | ConvertTo-json)`n}"
