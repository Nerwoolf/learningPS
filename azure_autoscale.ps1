<#
.SYNOPSIS
    Short description
.DESCRIPTION
    Long description
.EXAMPLE
    PS C:\> <example usage>
    Explanation of what the example does
.INPUTS
    Inputs (if any)
.OUTPUTS
    Output (if any)
.NOTES
    General notes
#>
param(
    # Resource group
    [Parameter(Mandatory=$true)]
    [String]
    $ResourseGroupName = "test",
    
    # Location
    [Parameter(Mandatory=$true)]
    [String]
    $Location = "westeurope"
)
begin{
    if(Get-AzureRmResourceGroup -Name $ResourseGroupName -ErrorAction SilentlyContinue){
        New-AzureRmResourceGroup -Name $ResourseGroupName -Location $Location
    }
    else {
        Write-Host ("{0} already exist" -f $ResourseGroupName)
    }
    $pubSettings = @{
        "fileUris" = (,"https://raw.githubusercontent.com/Azure-Samples/compute-automation-configurations/master/automate-iis.ps1");
        "commandToExecute" = "powershell -ExecutionPolicy Unrestricted -File automate-iis.ps1"
    }
    $vmSsSettings = @{
        ResourceGroupName = "$ResourseGroupName"
        Location = "$Location"
        VMScaleSetName = "$ResourseGroupName-scaleset"
        virtualNetworkName = "$ResourseGroupName-network"
        SubnetName = "$ResourseGroupName-subnet"
        publicIpAddressName = "$ResourseGroupName-pip"
        loadbalancername = "$ResourseGroupName-lb"
        upgradepolicymode = "Automatic"
    }
}
process{
    $vmScaleSet = new-azurermvmss @vmSsSettings
    Add-AzureRmVmssExtension -VirtualMachineScaleSet $vmScaleSet `
                             -Name "customScript" `
                             -Publisher "Microsoft.Compute" `
                             -Type "CustomScriptExtension" `
                             -TypeHandlerVersion 1.8 `
                             -Setting $pubSettings
    Update-AzureRmVmss -ResourceGroupName $ResourseGroupName -VirtualMachineScaleSet $vmScaleSet
    $autoScaleRule = New-AzureRmAutoscaleRule -MetricName "Percentage CPU" `
                                              -MetricResourceId $vmScaleSet.Id `
                                              -Operator GreaterThanOrEqual `
                                              -MetricStatistic Average `
                                              -Threshold 85 `
                                              -TimeGrain 00:01:00 `
                                              -ScaleActionCooldown 00:10:00 `
                                              -ScaleActionDirection Increase `
                                              -ScaleActionValue 2
    $VssProfile = New-AzureRmAutoscaleProfile -Name "$ResourseGroupName-autoscale" -DefaultCapacity 1 -MaximumCapacity 3 -MinimumCapacity 1 -Rule $autoScaleRule
    Add-AzureRmAutoscaleSetting -Location $Location -ResourceGroupName $ResourseGroupName -TargetResourceId $vmScaleSet.Id -AutoscaleProfile $VssProfile -Name "autoscale"
}
end{
    
}
