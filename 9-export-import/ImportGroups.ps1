$GraphEndpoint="https://graph.microsoft.com/beta"
$userFile=".\data\Users.json"
$usersFileLookup=".\data\UsersLookup.json"
$extAttrFile=".\data\ExtensionAttributes.json"
$groupsFile=".\data\Groups.json"
$groupsFileLookup=".\data\Groups.json"
$groupMembersFile=".\data\GroupMembers.json"
#
# Step 1 - Create the groups
#
$groups = ( Get-Content -Path $groupsFile | ConvertFrom-json)
$Lookup=@()
foreach( $group in $groups.groups ) {
    if ( $group.description -eq $null ) {
        $group.description = $group.displayName
    }
    $body = @"
{    
    "description": "$($group.description)",
    "displayName": "$($group.displayName)",
    "securityEnabled": true,
    "mailEnabled": false,
    "mailNickname": "$($group.mailNickname)"
}
"@
    try {
        $body
        $resp = Invoke-RestMethod -Method "POST" -Uri "$GraphEndpoint/groups" -Headers $authHeader -Body $body
        # save new group's id for the lookup table
        $Lookup += @{ id = $group.id; idNew = $resp.id }
    } catch {
        $streamReader = [System.IO.StreamReader]::new($_.Exception.Response.GetResponseStream())
        $streamReader.BaseStream.Position = 0
        $streamReader.DiscardBufferedData()
        $errResp = $streamReader.ReadToEnd()
        $streamReader.Close()    
        write-host $errResp -ForegroundColor "Red" -BackgroundColor "Black"
    }
}
Set-Content -Path $groupsFileLookup -Value "{ `"groups`":`n$($Lookup | ConvertTo-json)`n}"

#
# Step 2 - Add group members
#

# read the list of groups and members from the source system
$groupmembers = ( Get-Content $groupMembersFile | ConvertFrom-json)
# read the lookup list so we can map source objectId to target objectId
$usersLookup = ( Get-Content $usersFileLookup | ConvertFrom-json)

foreach( $group in $groupmembers.groupmembers ) {
    # translate source group Id to target
    $gid = ($Lookup | where {$_.id -eq $group.groupid}).idNew
    foreach( $member  in $group.members ) {
        # translate source user id to target
        $oid = ($usersLookup.users | where {$_.id -eq $member.id}).idNew
        if ( $oid -eq $null ) {
            Write-host "Unknown source user $($member.id)"
        } else {
            Write-host "Adding member $oid to group $gid"
            $body = @"
{ 
    "@odata.id": "$GraphEndpoint/directoryObjects/$oid"
}
"@
            try {
                $resp = Invoke-RestMethod -Method "POST" -Uri "$GraphEndpoint/groups/$gid/members/`$ref" -Headers $authHeader -Body $body
            } catch {
                $streamReader = [System.IO.StreamReader]::new($_.Exception.Response.GetResponseStream())
                $streamReader.BaseStream.Position = 0
                $streamReader.DiscardBufferedData()
                $errResp = $streamReader.ReadToEnd()
                $streamReader.Close()    
                write-host $errResp -ForegroundColor "Red" -BackgroundColor "Black"
            }
        }
    }
}
