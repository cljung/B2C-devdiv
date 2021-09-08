$targetTenantName = "yourtenant.onmicrosoft.com"
$GraphEndpoint="https://graph.microsoft.com/beta"
$usersFile=".\data\Users.json"
$usersFileLookup=".\data\UsersLookup.json"
$usersFileError=".\data\UsersError.json"
$extAttrFileLookup=".\data\ExtensionAttributesLookup.json"

# construct a passwordProfile entity as all objects need one during creation
$pwdProf =@{
    passwordProfile = @{
        password="YourComplexInitialPassword1234!!"; forceChangePasswordNextSignIn=$true; forceChangePasswordNextSignInWithMfa=$false
    }
}
$eaLookup = (Get-Content -Path $extAttrFileLookup | ConvertFrom-json)
$data = (Get-Content -Path $usersFile)
# do global string replace to update the names of the extension attributes
foreach( $ea in $eaLookup.attributes ) {
    if ( $ea.name -ne $null ) {
        $data = $data.Replace( $ea.name, $ea.nameNew )
    }
}
$data = ($data | ConvertFrom-json)
$usersLookup=@()
$usersErrors=@()
foreach( $user in $data.users ) {
    if ( $user.userPrincipalName -imatch "#EXT#" -or $user.userPrincipalName -imatch "graphexplorer" -or $user.userType -eq "Guest" -or $user.creationType -eq "Invitation") {
        continue
    }
    $idOld = $user.id
    # remove objectId and UPN as they are immutable and can't be imported
    $user.psobject.properties.Remove("id")
    $user.psobject.properties.Remove("userPrincipalName")
    # add a passwordProfile as all accounts need one
    if ( $user.passwordProfile -eq $null ) {
        $user | Add-Member -MemberType NoteProperty -Name "passwordProfile" -Value $pwdProf.passwordProfile
    } elseif ($user.creationType -eq "LocalAccount" -and $user.passwordProfile -ne $null ) {
        $user.passwordProfile.password = $pwdProf.passwordProfile.password
    }
    # remove the UPN item in the identities collection as it is created automatically on write
    $identities=@()
    $identities += $user.identities | where {$_.signInType -ne "userPrincipalName"}
    $user.psobject.properties.Remove("identities")
    $user | Add-Member -MemberType NoteProperty -Name "identities" -Value $identities
    # change all yourtenant.onmicrosoft.com to the real value
    foreach( $identity in $identities ) {
        if ( $identity.issuer.EndsWith(".onmicrosoft.com") ) {
            $identity.issuer = $targetTenantName
        }
    }
    $body = ($user | ConvertTo-json)
    #$body # dbg
    try {
        $resp = Invoke-RestMethod -Method "POST" -Uri "$GraphEndpoint/users" -Headers $authHeader -Body $body
        # save new user's id for the lookup table
        $usersLookup += @{ id = $idOld; idNew = $resp.id }
    } catch {
        $streamReader = [System.IO.StreamReader]::new($_.Exception.Response.GetResponseStream())
        $streamReader.BaseStream.Position = 0
        $streamReader.DiscardBufferedData()
        $errResp = $streamReader.ReadToEnd()
        $streamReader.Close()    
        write-host $errResp -ForegroundColor "Red" -BackgroundColor "Black"
        $usersErrors += @{ id = $idOld; error = $errResp }
    }
    <##>#>
}
Set-Content -Path $usersFileLookup -Value "{ `"users`":`n$($usersLookup | ConvertTo-json)`n}"
Set-Content -Path $usersFileError -Value "{ `"errors`":`n$($usersErrors | ConvertTo-json)`n}"
