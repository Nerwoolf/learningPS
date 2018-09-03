# var example
param (
     $ResourceGroup = "crgq2",
     $ApiMgmtName = "crgq2crgapi",
     $SwaggerUrl = "http://crgq2-businesscore.azurewebsites.net:80/swagger/docs/v1",
     $ApiSlotName = "Business Core Web API",
     $ApiDescr = "ColemanRG - $AzureAPImAPIName",
     $ApiServiceUrl = "http://crgq2-businesscore.azurewebsites.net",
     $ApiPath = "core",
     $Product = "CRG Developers",
     $Policies = '',
     $AzAdAppId = "c98e0590-c150-43cb-bdc0-29d526c8f48b",
     $AzAdAppSecret = "f4byDuKq8AThA0esQd+T+V6cK26J9ldIZz0X7V9jcgU=",
     $TenantId = "81344805-9ded-41a7-84d0-07de43703c43"
)
begin {  
    function Get-AzureRmCachedAccessToken(){
        $ErrorActionPreference = 'Stop'
        
        if(-not (Get-Module AzureRm.Profile)) {
            Import-Module AzureRm.Profile
        }
        $azureRmProfileModuleVersion = (Get-Module AzureRm.Profile).Version
        # refactoring performed in AzureRm.Profile v3.0 or later
        if($azureRmProfileModuleVersion.Major -ge 3) {
            $azureRmProfile = [Microsoft.Azure.Commands.Common.Authentication.Abstractions.AzureRmProfileProvider]::Instance.Profile
            if(-not $azureRmProfile.Accounts.Count) {
            Write-Error "Ensure you have logged in before calling this function."    
            }
        } else {
            # AzureRm.Profile < v3.0
            $azureRmProfile = [Microsoft.WindowsAzure.Commands.Common.AzureRmProfileProvider]::Instance.Profile
            if(-not $azureRmProfile.Context.Account.Count) {
            Write-Error "Ensure you have logged in before calling this function."    
            }
        }
        
        $currentAzureContext = Get-AzureRmContext
        $profileClient = New-Object Microsoft.Azure.Commands.ResourceManager.Common.RMProfileClient($azureRmProfile)
        Write-Debug ("Getting access token for tenant" + $currentAzureContext.Subscription.TenantId)
        $token = $profileClient.AcquireAccessToken($currentAzureContext.Subscription.TenantId)
        $token.AccessToken
    }

    
    $msOauth2Url = "https://login.microsoftonline.com/$TenantId/oauth2/token?api-version=1.0"
    $managementAzureUrl = "https://management.core.windows.net/"

    $getAzureBearerToken = Invoke-RestMethod -Uri $msOauth2Url `
                                             -Method Post `
                                             -Body @{
                                                     "grant_type"     = "client_credentials";
                                                     "resource"       = "$managementAzureUrl";
                                                     "client_id"      = "$AzAdAppId";
                                                     "client_secret"  = "$AzAdAppSecret"
                                             }
    $authHeader = @{
          'Authorization' = "Bearer $($getAzureBearerToken.access_token)"
          'Content-Type'='application/json'
    }  
    $body = @{
        properties = @{
            contentFormat = "swagger-link-json"
            contentValue = "http://crgq2-businesscore.azurewebsites.net:80/swagger/docs/v1"
            path = '3b9eb923ecd549488c21c82c8ee929df'
        }
    }
    # $body = @{
    #     displayName = "$ApiSlotName"
    #     serviceUrl = "http://crgq2-businesscore.azurewebsites.net:80/swagger/docs/v1"
    #     path = $ApiPath
    # }

    $updateApi = "https://management.azure.com/subscriptions/" + $subscriptionId +
                                                "/resourceGroups/" + $ResourceGroup + 
                                                "/providers/Microsoft.ApiManagement/service/" + $ApiMgmtName +
                                                "/apis/"+ "3b9eb923ecd549488c21c82c8ee929df?import=true" +
                                                "&api-version=2018-06-01-preview"
                                                
                                             vice/crgd2crgapi/apis/3b9eb923ecd549488c21c82c8ee929df?import=true&api-version=2018-01-01

    Invoke-RestMethod -Uri $updateApi –Headers $authHeader –Method put -Body ($body | ConvertTo-Json -Compress -Depth 3)

}
process{

}
end {

}