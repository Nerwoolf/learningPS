param(
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroupName = "crg",

    [Parameter(Mandatory=$true)]
    [string]$Location="Westeurope"
   
)
begin{
    # Silently continue runing if error received
$ErrorActionPreference = "SilentlyContinue"
    
    # Create resource group if not exist
if(Get-AzureRmResourceGroup -Name $ResourceGroupName){
    Write-host ("Resource group {0} already exist" -f $ResourceGroupName) 
} else {
    Write-host ("Creating resource group {0}" -f $ResourceGroupName)
    New-AzureRmResourceGroup -Name $ResourceGroupName -Location $Location
}

}
process{
    
 
}
end{

}