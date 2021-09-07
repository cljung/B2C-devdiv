$GraphEndpoint="https://graph.microsoft.com/beta"
$userFile=".\data\Users.json"
$extAttrFile=".\data\ExtensionAttributes.json"
$groupsFile=".\data\Groups.json"
$groupMembersFile=".\data\GroupMembers.json"
#
# Step 1 - Export all users (skip null values). 
# Save all extensions attributes so we can get their data types 
#
write-host "Exporting users to $userFile..."
$unneededProps=@("@odata.id", "businessPhones", "createdDateTime", "imAddresses", "infoCatalogs", "mailNickname", "proxyAddresses", 
        "refreshTokensValidFromDateTime", "signInSessionsValidFromDateTime", "assignedLicenses", "assignedPlans", 
        "deviceKeys", "onPremisesExtensionAttributes", "onPremisesProvisioningErrors", "provisionedPlans")
Set-Content -Path $userFile -Value "{ `"users`": ["
$sep = " "
$extensionAttributes=@()
$resp = Invoke-RestMethod -Method GET -Uri "$GraphEndpoint/users?`$top=10" -Headers $authHeader
$resp.value.Count
while ( $resp.'@odata.nextLink' ) {
    foreach( $user in $resp.value ) {
        # get a list of props that have non-null values (we don't need to export/import nulls)
        $nonNullProps = ($user.psobject.properties.name).Where({ $null -ne $user.$_ })
        # remove some props that  doesn't make sense for B2C
        foreach( $name in $unneededProps) {
            $nonNullProps.Remove( $name ) | Out-null
        }
        # collect a list of any extension attributes so we can export their definition later
        $extensionAttributes += ($nonNullProps | where {$_.StartsWith("extension_")})
        # export the user
        $row = ($user | Select-Object $nonNullProps | ConvertTo-json -Compress)
        Add-Content -Path $userFile -Value "$sep$row"
        $sep = ","
    }
    $resp = Invoke-RestMethod -Method GET -Uri $resp.'@odata.nextLink' -Headers $authHeader
    $resp.value.Count
}
# make the list of extension attributes unique (remove dups)
$extensionAttributes = $extensionAttributes | select -Unique
Add-Content -Path $userFile -Value "]`n}"

#
# Step 2 - Create a list of all Extension Attributes used by the users. We need them to properly import the users in the target system
#
write-host "Exporting extension attributes to $extAttrFile..."
# Get all Apps used extension attributes
$appIDs=@()
foreach( $extName in $extensionAttributes ) {
    $appIDs += ($extName.Substring(10,8) + "-" + $extName.SubString(18,4) + "-" + $extName.SubString(22,4) + "-" + $extName.Substring(26,4) + "-" + $extName.Substring(30,12))
}
$appIDs = $appIDs | select -Unique
# Get all extension attributes datatypes
$earr=@()
foreach( $appId in $appIDs) {
    $resp = Invoke-RestMethod -Method GET -Uri "$GraphEndpoint/applications?`$filter=AppId eq '$($appId)'&`$select=id,displayName" -Headers $authHeader 
    $appName = $resp.value.displayName
    $appObjectId = $resp.value.id
    $resp = Invoke-RestMethod -Method GET -Uri "$GraphEndpoint/applications/$appObjectId/extensionProperties?`$select=name,dataType" -Headers $authHeader 
    $attribs=@()
    foreach( $eProp in $resp.value ) {
        $attribs += @{ name = $eProp.name.Substring(43); dataType = $eProp.dataType }
    }
    $appExtAttr = @{ appName=$appName; appId=$appId; objectId=$appObjectId; extensionAttributes = @($attribs) }
    $earr += $appExtAttr
}
Set-Content -Path $extAttrFile -Value "{ `"attributes`":`n$($earr | ConvertTo-json -Depth 10)`n}"

#
# Step 3 - Export all groups
#
write-host "Exporting groups $groupsFile..."
Set-Content -Path $groupsFile -Value "{ `"groups`": ["
$sep = " "
$groupIds=@()
$resp = Invoke-RestMethod -Method GET -Uri "$GraphEndpoint/groups?`$top=5&`$select=id,description,displayName,mailNickname" -Headers $authHeader
$resp.value.Count
while ( $resp.'@odata.nextLink' ) {
    foreach( $group in $resp.value ) {
        $group.psobject.properties.Remove("@odata.id")
        $row = ($group | ConvertTo-json -Compress)
        Add-Content -Path $groupsFile -Value "$sep$row"
        $sep = ","
        $groupIds += $group.id
    }
    $resp = Invoke-RestMethod -Method GET -Uri $resp.'@odata.nextLink' -Headers $authHeader
    $resp.value.Count
}
Add-Content -Path $groupsFile -Value "]`n}"

#
# Step 4 - Export all group members
#
write-host "Exporting group members $groupMembersFile..."
Set-Content -Path $groupMembersFile -Value "{ `"groupmembers`": ["
$sep = " "
foreach( $id in $groupIds ) {
    $resp = Invoke-RestMethod -Method GET -Uri "$GraphEndpoint/groups/$id/members?`$select=id" -Headers $authHeader
    $members=@()
    foreach( $member in $resp.value ) {
        if ( $member."@odata.type" -eq "#microsoft.graph.user" ) {
            $members += @{ type = "user"; id = $member.id }
        } else {
            $members += @{ type = "group"; id = $member.id }
        }
    }
    $group = @{ groupid=$id; members = @($members) }
    $row = ($group | ConvertTo-json -Compress)
    Add-Content -Path $groupMembersFile -Value "$sep$row"
    $sep = ","
}
Add-Content -Path $groupMembersFile -Value "]`n}"