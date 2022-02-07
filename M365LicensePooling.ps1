#Include Graph API functions
. .\Send-M365ApiRequest.ps1

$reportFileName = "report_licenses_groups_m365"
$configFile = Get-Content .\config.json | ConvertFrom-Json
$kronoStart = Get-Date

Function Get-LicenseName {
    Param(
        [string]$SkuId,
        [string]$ServicePlanId
    )
    try{
        $skumap = Get-Content -Path .\skumap.json -ErrorAction Stop | ConvertFrom-Json
        if($SkuId){
            $licenseName = $skumap | Where-Object{$_.GUID -eq $SkuId} | Select-Object -First 1
        }
        else{
            $licenseName = $skumap | Where-Object{$_.Service_Plan_Id -eq $ServicePlanId} | Select-Object -First 1
        }
        
        return $licenseName
    }
    catch{
        return $_.Exception.Message
    }
    
}

#Function to create a Write-Log file and register Write-Log entries
Function Write-Log{
    Param(
        [Parameter(Mandatory=$true)][string]$Status,
        [Parameter(Mandatory=$true)][string]$Message
    )
    
    $logName = $installDir + ".\$(Get-Date -Format 'dd-MM-yyyy').log"

    $dayLogFile = Test-Path $logName
    
    $dateTime = Get-Date -Format dd/MM/yyyy-HH:mm:ss

    If($dayLogFile -eq $true){

        $logLine = $dateTime + "," + $Status + "," + $Message
        $logLine | Out-File -FilePath $logName -Append
    }
    Else
    {
        $header = "Date,Status,Message"
        $header | Out-File -FilePath $logName
        $logLine = $dateTime + "," + $Status + "," + $Message
        $logLine | Out-File -FilePath $logName -Append
    }
}

Write-Log -Status "Info" -Message "#### Execucao iniciada ####"

$m365GroupsRequest = Send-M365ApiRequest -TenantId $configFile.tenantId `
-ApplicationId $configFile.applicationId `
-ClientSecret $configFile.clientSecret `
-Api Graph `
-Method Get `
-Path "/groups?`$select=id,displayName,assignedLicenses"#&`$filter=id eq '419c2534-9a89-4b8b-9bc7-4a4464165bfd'"

Write-Log -Status "Info" -Message "Grupos encontrados: $(($m365GroupsRequest|Measure-Object).Count)"

$m365GroupsObj = @()
$i = 1

foreach($group in $m365GroupsRequest) {

    Write-Log -Status "Info" -Message "Obtendo licencas do grupo $($i) de $(($m365GroupsRequest|Measure-Object).Count). Grupo: $($group.displayName)"

    $assignedLicenses = @()
    foreach($license in $group.assignedLicenses){
        $disabledPlans = @()
        foreach($plan in $license.disabledPlans) {
            $disabledPlan = [PSCustomObject]@{
                DisabledPlanName = (Get-LicenseName -ServicePlanId $plan).Service_Plans_Included_Friendly_Names
            }
            $disabledPlans += $disabledPlan.DisabledPlanName
        }
        $assignedLicense = [PSCustomObject]@{
            SkuName = (Get-LicenseName -SkuId $license.skuId).Product_Display_Name
            DisabledPlans = $disabledPlans
        }
        $assignedLicenses += $assignedLicense
    }

    Write-Log -Status "Info" -Message "Licencas obtidas com sucesso. Iniciando listagem de membros do grupo $($group.displayName)"

    $groupMembers = Send-M365ApiRequest -TenantID $configFile.tenantId `
    -ApplicationId $configFile.applicationId `
    -ClientSecret $configFile.clientSecret `
    -Api Graph `
    -Method Get `
    -Path /Groups/$($group.id)/members

    Write-Log -Status "Info" -Message "Foram encontrados $(($groupMembers|Measure-Object).Count) membros no grupo $($group.displayName)"

    foreach ($member in $groupMembers) {

        $m365GroupsAssignedLicenses = [PSCustomObject]@{
            groupId = $group.id
            groupDisplayName = $group.displayName
            groupAssignedLicenses = $assignedLicenses
            userId = $member.id
            userPrincipalName = $member.userPrincipalName
            userDisplayName = $member.displayName
            userMail = $member.mail
        }
        $m365GroupsObj += $m365GroupsAssignedLicenses
    }
    $i++
}

Write-Log -Status "Info" -Message "Exportando resultados para o arquivo $($reportFileName).csv"

$m365GroupsObj | Select-Object groupId,groupDisplayName,@{n="groupAssignedLicensesDisabledPlans";e={$_.groupAssignedLicenses.disabledPlans -join '|'}},@{n="groupAssignedLicensesSkuNames";e={$_.groupAssignedLicenses.SkuName -join '|'}},@{n="userId";e={$_.userId -join '|'}},@{n="userPrincipalName";e={$_.userPrincipalName -join '|'}},@{n="userDisplayName";e={$_.userDisplayName -join '|'}},@{n="userMail";e={$_.userMail -join '|'}} | Export-Csv .\"$($reportFileName).csv" -NoTypeInformation

$kronoEnd = Get-Date
Write-Log -Status "Info" -Message "Execucao concluida. Tempo de execucao: $((New-TimeSpan -Start $kronoStart -End $kronoEnd).ToString())"