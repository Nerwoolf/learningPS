<#
.SYNOPSIS
    learn.ps1
.DESCRIPTION
    This script deploy VMs in high availability set  with Load balancer
.EXAMPLE

#>
param(
    [Parameter(Mandatory=$true)]
    [String]$resourceGroup,

    [Parameter(Mandatory=$true)]
    [String]$location,

    [Parameter(Mandatory=$true)]
    [int]$VMNumber
)
begin{
       # Connect to Azure
    try {
        Get-AzureRmSubscription
    }
    catch {
        Connect-AzureRmAccount
    }

    $cred = Get-Credential -Message "Credentials for VM admin account"
        # VMs configuration
    
        # Security rules
        $secRuleVars = @{
            Access = 'Allow'
            Protocol = 'Tcp' 
            Direction = 'Inbound'
            SourceAddressPrefix = "*"
            SourcePortRange = "*"
            DestinationAddressPrefix = "*"
        }



}
process{
    New-AzureRmResourceGroup -Name $resourceGroup -Location $location 
    # Create VMs
    # Create Availbility set
    $availSet = New-AzureRmAvailabilitySet -ResourceGroupName $resourceGroup -Location $location -name "AvailSet"`
    -PlatformUpdateDomainCount 2 -PlatformFaultDomainCount 2 -Sku Aligned
    # Create NSG Rules 
    $rule1 = New-AzureRmNetworkSecurityRuleConfig -Name 'RDP-Allow' @secRuleVars -Priority 100 -DestinationPortRange 3389
    $rule2 = New-AzureRmNetworkSecurityRuleConfig -Name 'HTTP-Allow' @secRuleVars -Priority 101 -DestinationPortRange 80

    # Create public IP
    $publicIP = New-AzureRmPublicIpAddress `
    -ResourceGroupName "$resourceGroup" `
    -Location "$location" `
    -AllocationMethod "Dynamic" `
    -Name "PublicIP"
    # Create NetworkSecurity group 
    $nsg = New-AzureRmNetworkSecurityGroup -Name 'NSG' -ResourceGroupName $resourceGroup -Location $location -SecurityRules $rule1, $rule2

    # Create Subnet
    $subnet = New-AzureRmVirtualNetworkSubnetConfig -Name 'Subnet' -AddressPrefix '192.168.0.0/24' -NetworkSecurityGroupId $nsg.id

    # Create VirtualNet
    $virtNet = New-AzureRmVirtualNetwork -Name 'VirtNet' -ResourceGroupName $resourceGroup -Location $location `
    -AddressPrefix '192.168.0.0/16' -subnet $subnet

    # FrontEnd pool
    $FEpool = New-AzureRmLoadBalancerFrontendIpConfig -Name "FRontEndIp" -PublicIpAddress $publicIP
    
    # BackEnd pool
    $BEpool = New-AzureRmLoadBalancerBackendAddressPoolConfig -Name "BackEndPool"
    # Create probe
    $probe = New-AzureRmLoadBalancerProbeConfig -Name "HTTP" -Port 80 -Protocol tcp -IntervalInSeconds 20 -ProbeCount 5
    # Create rule 
    $LBrool = New-AzureRmLoadBalancerRuleConfig -Name "LBRool" -FrontendIpConfiguration $FEpool -BackendAddressPool $BEpool `
    -Probe $probe -Protocol tcp -FrontendPort 80 -BackendPort 80
    # Create LoadBalancer
    $loadBalancer = New-AzureRmLoadBalancer -Name "LB" -ResourceGroupName $resourceGroup -Location $location -LoadBalancingRule $LBrool `
    -FrontendIpConfiguration $FEpool -BackendAddressPool $BEpool -Probe $probe 
    # Create nat rules
<#$natrules = @{}
    for($i=1; $i -le $VMNumber; $i++){
        $natrules[$i] = New-AzureRmLoadBalancerInboundNatRuleConfig -Name "RDP-VM$i" -Protocol tcp -FrontendPort "5000$i" -b
    }#>
     

    # Create network adapters
    $nics = @{}
    
    for($i=1; $i -le $VMNumber; $i++){
      $nics[$i] = New-AzureRmNetworkInterface -ResourceGroupName $resourceGroup -Location $location `
        -Name "MyNic$i" -LoadBalancerBackendAddressPool $BEpool -NetworkSecurityGroup $nsg `
        -Subnet $virtNet.Subnets[0] 
        }

    # Create VM with configuring
   
   
    for($i=1; $i -le $VMNumber; $i++){
    
        $vmConfig = New-AzureRmVMConfig -VMName "VM$i" -VMSize Standard_A2_v2 -AvailabilitySetId $availSet.Id | `
        Set-AzureRmVMOperatingSystem -Windows -ComputerName "VM$i" -Credential $cred | `
        Set-AzureRmVMSourceImage -PublisherName MicrosoftWindowsServer -Offer WindowsServer `
        -Skus 2016-Datacenter -Version latest | Add-AzureRmVMNetworkInterface -Id $nics[$i].id

        New-AzureRmVM -ResourceGroupName $resourceGroup -Location $location -VM $vmConfig 
}
    # Setting up IIS service
    for($i=1; $i -le $VMNumber; $i++){
    Set-AzureRmVMExtension -ResourceGroupName "$resourceGroup" `
    -ExtensionName "IIS" `
    -VMName "VM$i" `
    -Location "$location" `
    -Publisher Microsoft.Compute `
    -ExtensionType CustomScriptExtension `
    -asjob `
    -TypeHandlerVersion 1.8 `
    -SettingString '{"commandToExecute":"powershell Add-WindowsFeature Web-Server; powershell Add-Content -Path \"C:\\inetpub\\wwwroot\\Default.htm\" -Value $($env:computername)"}'
    }
}
end{
    Get-AzureRmPublicIpAddress -ResourceGroupName $resourceGroup | Select-Object -Property ipaddress
}
