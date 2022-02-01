#Include Graph API functions
. .\Send-M365ApiRequest.ps1

$m365GroupsRequest = Send-M365ApiRequest -ClientId "88806a6c-1a2f-4855-b4fe-824de636dee2" `
-ClientSecret "je4hb4l74N_~6-SuGV._DjZ3w.XEP7z7w~" `
-TenantId "cdcae3ff-a663-4732-9cf5-1e33db81acf1" `
-Api Graph `
-Method Get `
-Path "/groups?`$select=id,displayName,assignedLicenses"#&`$filter=id eq '419c2534-9a89-4b8b-9bc7-4a4464165bfd'"
    

$m365GroupsObj = @()

foreach($group in $m365GroupsRequest) {

    $groupMembers = Send-M365ApiRequest -ClientId "88806a6c-1a2f-4855-b4fe-824de636dee2" `
    -ClientSecret "je4hb4l74N_~6-SuGV._DjZ3w.XEP7z7w~" `
    -TenantId "cdcae3ff-a663-4732-9cf5-1e33db81acf1" `
    -Api Graph `
    -Method Get `
    -Path /Groups/$($group.id)/members

    $m365GroupsAssignedLicenses = [PSCustomObject]@{
        id = $group.id
        displayName = $group.displayName
        assignedLicenses = $group.assignedLicenses
        members = $groupMembers
    }

    $m365GroupsObj += $m365GroupsAssignedLicenses
}

$m365GroupsObj | Select-Object id,displayName,@{n="assignedLicensesDisabledPlans";e={$_.assignedLicenses.disabledPlans -join '|'}},@{n="assignedLicensesSkuIds";e={$_.assignedLicenses.SkuId -join '|'}},@{n="membersId";e={$_.members.id -join '|'}},@{n="membersDisplayName";e={$_.members.displayName -join '|'}},@{n="membersUpn";e={$_.members.userPrincipalName -join '|'}},@{n="membersMail";e={$_.members.mail -join '|'}} | Export-Csv .\groups.csv -NoTypeInformation