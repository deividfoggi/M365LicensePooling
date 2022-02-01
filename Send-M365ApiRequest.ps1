<#
.SYNOPSIS
Send requests to Microsoft 365 Cloud APIs. The script currently supports Graph API and Office 365 Management API. You don't need anything like libraries or SDKs
to run a simple test and either confirm if an app permission is working or if a request is being returned as expected. It is necessary to have only the minimum
requirement: an app registration in Azure AD with the appropriate permission to request the respective Api.

.DESCRIPTION
This script will make a request to the API informed in the appropriate parameter and return the results. You just need to fullfil all parameters
as expected by the API documentation to receive the response. Obviously, it is expected that you have a application registration in a Azure AD tenant already created.
You can use both client credentials flow (Application Permission Type) and authorization code flow (Delegated Permission Type).

.PARAMETER ClientID
The client id attribute from Application Registration in Azure AD.

.PARAMETER TenantID
The tenant id attibute from Application Registratoin in Azure AD.

.PARAMETER ClientSecret
The client secret from Applition Registration in Azure AD.

.PARAMETER Method
HTTP method to be used in the request.

.PARAMETER Path
Path that will be appended in the Graph API root URI (https://graph.microsoft.com/v1.0)

.PARAMETER Json
Optional json file to be send as HTTP body in the request.

.PARAMETER Api
The API to request. Supported APIs are Graph, GraphBeta and ManagementApi

.PARAMETER Operation
Operation that will be used when contacting ManagementApi. Supported operations are Start, Stop, List and Content. The script doesn't support the usage of
Start operation with a webhook.

.PARAMETER ContentType
The content type to be returned when using ManagementApi. Supported content types are Audit.AzureActiveDirectory, Audit.Exchange, Audit.SharePoint, Audit.General and Dlp.All.

.INPUTS
It is possible to use the Json parameter to send inputs to the Api, for instance, when creating a user or sending an email.

.OUTPUTS
There are requests that is expected to return a body. Please follow the Api documentation to check if the request you're making is supposed to return a response.

.EXAMPLE
The following example will get all users from Graph 1.0 endpoint in a tenant using client credentials grant flow:

Send-M365ApiRequest.ps1 -ClientID XYZ -TenantID XYZ -ClientSecret XYZ -Api Graph -Method Get -Path /users

.EXAMPLE
The example below will start a subscription for Exchange Audit logs and after list all log entries in each blob:

Send-M365ApiRequest.ps1 -ClientID XYZ -TenantID XYZ -ClientSecret XYZ -Api ManagementApi -Method Post -Operation Start -ContentType Audit.Exchange
Send-M365ApiRequest.ps1 -ClientID XYZ -TenantID XYZ -ClientSecret XYZ -Api ManagementApi -Method Get -Operation Content -ContentType Audit.Exchange

.EXAMPLE
This example shows how to list currently subscriptions in Management Api:

Send-M365ApiRequest.ps1 -ClientID XYZ -TenantID XYZ -ClientSecret XYZ -Api ManagementApi -Method Get -Operation List

.LINK
https://github.com/deividfoggi/Send-M365ApiRequest
#>

Function Send-M365ApiRequest {

    Param(
        [Parameter(Mandatory=$true)]
        $ClientID,
        [Parameter(Mandatory=$true)]
        $TenantID,
        [Parameter(Mandatory=$true)]
        $ClientSecret,
        [Parameter(Mandatory=$true)]
        [ValidateSet("Get","Post","Patch","Delete","Put")]
        $Method,
        [Parameter(Mandatory=$false)]
        $Path,
        [Parameter(Mandatory=$false)]
        $Json,
        [Parameter(Mandatory=$true)]
        [ValidateSet("Graph","GraphBeta","ManagementApi")]
        $Api,
        [Parameter(Mandatory=$false)]
        [ValidateSet("Start","Stop","List","Content")]
        $Operation,
        [Parameter(Mandatory=$false)]
        [ValidateSet("Audit.AzureActiveDirectory","Audit.Exchange","Audit.SharePoint","Audit.General","DLP.All")]
        $ContentType
    )

    Function Get-AzureOAuthToken{
        Param(
            [Parameter(Mandatory=$true)]$ClientID,
            [Parameter(Mandatory=$true)]$TenantID,
            [Parameter(Mandatory=$false)]$TenandDomain,
            [Parameter(Mandatory=$false)]$ClientSecret,
            [Parameter(Mandatory=$false)]$Api,
            [Parameter(Mandatory=$false)]$OnBehalfOf,
            [Parameter(Mandatory=$false)]$RedirectUrl
        )

        $ClientSecret = [System.Uri]::EscapeDataString($ClientSecret)
        
        switch -Wildcard ($Api) {
            "Graph*" {
                if($OnBehalfOf -eq $true){
                    try{
                        $stringUrl = "https://login.microsoft.com/" + $tenantID + "/oauth2/v2.0/authorize?client_id=" + $clientId + "&response_type=code&redirect_uri=" + $RedirectUrl + "&response_mode=query&scope=Calendars.ReadWrite&state=12345"
                        Write-Host $stringUrl
                        $authCode = Read-Host "Paste the authorization code here"
                        $stringUrl = "https://login.microsoftonline.com/" + $tenantId + "/oauth2/v2.0/token"
                        $postData = "client_id=" + $clientId + "&scope=Calendars.ReadWrite&code=" + $authCode + "&redirect_uri=" + $RedirectUrl + "&grant_type=authorization_code&client_secret=" + $clientSecret
                        $accessToken = Invoke-RestMethod -Method Post -Uri $stringUrl -ContentType "application/x-www-form-urlencoded" -Body $postData -ErrorAction Stop
                        return $accessToken
                    }
                    catch{
                        Write-Warning -Message $_.Exception.Message
                    }
                }
                else{
                    $stringUrl = "https://login.microsoftonline.com/" + $tenantId + "/oauth2/v2.0/token"
                    $postData = "client_id=" + $clientId + "&scope=https://graph.microsoft.com/.default&client_secret=" + $clientSecret + "&grant_type=client_credentials"
                    try{
                        $accessToken = Invoke-RestMethod -Method post -Uri $stringUrl -ContentType "application/x-www-form-urlencoded" -Body $postData -ErrorAction Stop
                        return $accessToken
                    }
                    catch{
                        Write-Warning -Message $_.Exception.Message
                    }
                }

            }
            "ManagementApi" {
                $stringUrl = "https://login.microsoftonline.com/" + $tenantID + "/oauth2/token?api-version=1.0"
                $postData = @{grant_type = "client_credentials"; resource = "https://manage.office.com"; client_id = $clientID; client_secret = $clientSecret}
                try {
                    $accessToken = Invoke-RestMethod -Method Post -Uri $stringURL -Body $postData -ErrorAction Stop
                    return $accessToken
                }
                catch {
                    Write-Warning -Message $_.Exception.Message
                }
            }

            Default {
                Write-Host -ForegroundColor Yellow "Please select a service: Graph or Mgmt"
            }
        }
    }

    switch ($Api) {
        "Graph" { 
            $Uri = "https://graph.microsoft.com/v1.0" + $Path 
        }
        "GraphBeta" { 
            $Uri = "https://graph.microsoft.com/Beta" + $Path 
        }
        "ManagementApi" { 
            if(!$TenantID){
                Write-Warning "TenantID is mandatory when Api is ManagementApi."
                Exit
            }
            $Uri = "https://manage.office.com/api/v1.0/$($TenantID)/activity/feed/subscriptions/$($Operation)?contentType=$($ContentType)"
            }
    }

    #Gets a token
    $BearerToken = Get-AzureOAuthToken -ClientID $ClientID -TenantID $TenantID -ClientSecret $ClientSecret -Api $Api

    #Creates an empty array to store the appended results in case of paging
    $queryResults = @()

    if($Api -match "Graph"){
        #Do the HTTP request against the API endpoint until there is no @odata.nextLink in the response meaning no further pages
        do{
            try{
                #Stores the rest method request agains API in a variable
                $request = Invoke-RestMethod -Method $Method -Headers @{Authorization = "Bearer $($BearerToken.access_token)"} -Uri $Uri -ContentType "application/json" -Body $Json -ErrorAction Stop
                #$request
            }catch{             
                $_.Exception
            }
            #If varaible has a value property with content means there is results/payload
            if($request.value){
                #Adds the result/payload objects in the array
                $queryResults += $request.value
            }
            else{
                #If not, adds the entire response in the array
                $queryResults += $request
            }
            #Stores the @odata.nextLink in the variable used to check if there is further pages
            $Uri = $request.'@odata.nextLink'
        } until (!($Uri))
        #Returns the array containing all pages appended
        return $queryResults
    }
    else {
        try{
            $request = Invoke-RestMethod -Method $Method -Headers @{Authorization = "Bearer $($BearerToken.access_token)"} -Uri $Uri -ContentType "application/json" -ErrorAction Stop
            if($Operation -eq "Content"){
                foreach($item in $request){
                    $queryResults += Invoke-RestMethod -Method $Method -Headers @{Authorization = "Bearer $($BearerToken.access_token)"} -Uri $item.contentUri -ContentType "application/json" -ErrorAction Stop
                }
            }
            else {
                $queryResults = $request
            }
            $queryResults
        }
        catch{
            $_.Exception
        }
    }
}