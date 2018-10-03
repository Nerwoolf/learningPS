$rgFrance = "france"
$rgMoscow = "Moscow"
$LocFrance= "westeurope"
$locaMoscow = "francecentral"

# VM config
$vmFrance = @{
    
}
$vmMoscow =-@{

}
New-AzureRmResourceGroup -Name $rgFrance -Location $LocFrance
New-AzureRmResourceGroup -Name $rgMoscow -Location $locaMoscow

new-azurermvm -Name "$rgFrance-vm" -
