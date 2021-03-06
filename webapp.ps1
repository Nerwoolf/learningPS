<#
.SYNOPSIS
    Short description
.DESCRIPTION
    Long description
.EXAMPLE
    PS C:\> webapp.ps1 -ResourceGroup testgroup -Location westeurope
    This script will create 1 web service plan and 5 web applications in it. 
#>
param(
    [Parameter(Mandatory=$true)]
    [String]$resourceGroup = "newcrg",

    [Parameter(Mandatory=$true)]
    [String]$location = "westeurope"
    

)
begin{
    
    # Define and initialize variables     
    $webAppName = $resourceGroup+'-web'
    $servicePlanName = $webAppName+"serviceplan"
    $webAppNumber = 1
    $gitrepo="https://github.com/dotnet-architecture/eShopOnWeb.git"
    # Configure GitHub deployment to the staging slot from your GitHub repo and deploy once.
    $PropertiesObject = @{
    repoUrl = "$gitrepo";
    branch = "master";
}
}
process{

    # Create resource group
    if(!(Get-AzureRmResourceGroup | Where-Object -Property ResourceGroupName -eq "$resourceGroup")){
        New-AzureRmResourceGroup -Name $resourceGroup -Location $location
    }
    else {
        Write-host  "Group has already created"
    }

    # Create service plan
    $webServicePlan = New-AzureRmAppServicePlan -ResourceGroupName $resourceGroup -Location $location -Name "$servicePlanName-01" -NumberofWorkers 2 -WorkerSize small -Tier basic

    # Create number (= $webAppNumber) web application 
    for ($i=1; $i -le $webAppNumber; $i++){
        New-AzureRmWebApp -Name "$webAppName-$i" -ResourceGroupName $resourceGroup -AppServicePlan $webServicePlan.Name

        New-AzureRmWebAppSlot -Name "$webAppName-$i" -ResourceGroupName $resourceGroup -Slot staging

        Set-AzureRmResource -PropertyObject $PropertiesObject -ResourceGroupName $resourceGroup -ResourceType Microsoft.Web/sites/slots/sourcecontrols -ResourceName "$webAppName-$i/staging/web" -ApiVersion 2015-08-01 -Force
        
    }

    

}
end{    
}