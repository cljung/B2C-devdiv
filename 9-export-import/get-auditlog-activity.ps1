$GraphEndpoint="https://graph.microsoft.com/v1.0"
$resp = Invoke-RestMethod -Method GET -Headers $authHeader -Uri "$GraphEndpoint/auditLogs/directoryAudits?`$top=10&`$filter=activityDisplayName eq 'Add user' or activityDisplayName eq 'Delete user'"
$more = $true
while ( $more ) {
    $resp.value.Count
    foreach( $item in $resp.value ) {
        write-host $item.activityDateTime $item.activityDisplayName $item.targetResources.Id 
        write-host ($item.targetResources.modifiedProperties | ConvertTo-json)
    }
    if ( $resp.'@odata.nextLink' ) {
         $resp = Invoke-RestMethod -Method GET -Uri $resp.'@odata.nextLink' -Headers $authHeader
    } else {
        $more = $false
    }
}
