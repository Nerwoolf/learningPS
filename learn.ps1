<#
.SYNOPSIS
    learn.ps1
.DESCRIPTION
    This script deploy VMs in high availability set  with Load balancer
.EXAMPLE

#>
param(
    [Parameter(Mandatory=$true)]
    [String]$resourceGroup = "crg",

    [Parameter(Mandatory=$true)]
    [String]$location = "westeurope",

    $vmNumber = "2",
    $vmName = $resourceGroup + '-vm',
    $vmSize = "Standard_A2"
)
begin{
       # Connect to Azure
    try {
        Get-AzureRmSubscription
    }
    catch {
        Connect-AzureRmAccount
    }

        # Check for resourcegroup 
    if(!(Get-AzureRmResourceGroup -Name $resourceGroup -ErrorAction SilentlyContinue)){

        # Create resource group
        Write-Verbose -Message "Creating new group with name: $resourceGroup"
        New-AzureRmResourceGroup -Name $resourceGroup -Location $location
    
    }   

        # Create new storage account
        $storAccount = New-AzureRmStorageAccount -Name "$resourceGroup`storage01" `
                                                 -ResourceGroupName $resourceGroup `
                                                 -Location $location `
                                                 -SkuName Standard_GRS `
                                                 -Kind StorageV2 


        # Get cred for VM admin user.
        $cred = Get-Credential -Message "Credentials for VM admin account"
    
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
 
    # Create Availbility set
    $availSet = New-AzureRmAvailabilitySet -ResourceGroup $resourceGroup `
                                           -Location $location `
                                           -name "$resourceGroup-availset-01" `
                                           -PlatformUpdateDomainCount 2 `
                                           -PlatformFaultDomainCount 2 `
                                           -Sku Aligned
    # Create NSG Rules 
    $rule1 = New-AzureRmNetworkSecurityRuleConfig -Name 'RDP-Allow' @secRuleVars -Priority 100 -DestinationPortRange 3389
    $rule2 = New-AzureRmNetworkSecurityRuleConfig -Name 'HTTP-Allow' @secRuleVars -Priority 101 -DestinationPortRange 80

    # Create public IP
    $publicIP = New-AzureRmPublicIpAddress -ResourceGroup "$resourceGroup" `
                                           -Location "$location" `
                                           -AllocationMethod "Dynamic" `
                                           -Name "$resourceGroup-pip-01"
    # Create NetworkSecurity group 
    $nsg = New-AzureRmNetworkSecurityGroup -Name "$resourceGroup-nsg-01" `
                                           -ResourceGroup $resourceGroup `
                                           -Location $location `
                                           -SecurityRules $rule1, $rule2

    # Create Subnet
    $subnet = New-AzureRmVirtualNetworkSubnetConfig -Name "$resourceGroup-backend-subnet-01" `
                                                    -AddressPrefix '192.168.0.0/24' `
                                                    -NetworkSecurityGroupId $nsg.id

    # Create VirtualNet
    $virtNet = New-AzureRmVirtualNetwork -Name "$resourceGroup-virtnet-01" `
                                         -ResourceGroup $resourceGroup `
                                         -Location $location `
                                         -AddressPrefix '192.168.0.0/16' `
                                         -subnet $subnet

    # FrontEnd pool
    $fePool = New-AzureRmLoadBalancerFrontendIpConfig -Name "$resourceGroup-feip-01" -PublicIpAddress $publicIP
    
    # BackEnd pool
    $bePool = New-AzureRmLoadBalancerBackendAddressPoolConfig -Name "$resourceGroup-bepool-01"

    # Create probe
    $probe = New-AzureRmLoadBalancerProbeConfig -Name "HTTP" `
                                                -Port 80 `
                                                -Protocol tcp `
                                                -IntervalInSeconds 20 `
                                                -ProbeCount 5
    
    # Create rule 
    $LBrool = New-AzureRmLoadBalancerRuleConfig -Name "LBRool" `
                                                -FrontendIpConfiguration $FEpool `
                                                -BackendAddressPool $BEpool `
                                                -Probe $probe `
                                                -Protocol tcp `
                                                -FrontendPort 80 `
                                                -BackendPort 80

    # Create Nat inboun rule
    $inNatLoadBalRule1 = New-AzureRmLoadBalancerInboundNatRuleConfig -Name "$vmName-rdp-1" `
                                                                    -FrontendIpConfiguration $fePool `
                                                                    -Protocol Tcp `
                                                                    -FrontendPort 50000 `
                                                                    -BackendPort 3389

    $inNatLoadBalRule2 = New-AzureRmLoadBalancerInboundNatRuleConfig -Name "$vmName-rdp-2" `
                                                                    -FrontendIpConfiguration $fePool `
                                                                    -Protocol Tcp `
                                                                    -FrontendPort 50001 `
                                                                    -BackendPort 3389
                                                                    

    # Create LoadBalancer
    $loadBalancer = New-AzureRmLoadBalancer     -Name "$resourceGroup-loadbal-01" `
                                                -ResourceGroup $resourceGroup `
                                                -Location $location `
                                                -LoadBalancingRule $LBrool `
                                                -FrontendIpConfiguration $FEpool `
                                                -BackendAddressPool $BEpool `
                                                -Probe $probe `
                                                -InboundNatRule $inNatLoadBalRule1, $inNatLoadBalRule2

    # Create network adapters
    $nics = @{}
    
    for($i=1; $i -le $VMNumber; $i++){
        
        $nics[$i] = New-AzureRmNetworkInterface -ResourceGroup $resourceGroup `
                                                -Location $location `
                                                -Name "$vmName-$i-nic" `
                                                -LoadBalancerBackendAddressPool $BEpool `
                                                #-NetworkSecurityGroup $nsg `
                                                -Subnet $virtNet.Subnets[0] `
                                                -LoadBalancerInboundNatRule (Get-AzureRmLoadBalancerInboundNatRuleConfig -LoadBalancer $loadBalancer)[$i]
    }

    # Create VM with configuring
    for($i=1; $i -le $VMNumber; $i++){
    
        $vmConfig = New-AzureRmVMConfig -VMName "$vmName-$i" `
                                        -VMSize $vmSize `
                                        -AvailabilitySetId $availSet.Id |`
                    Set-AzureRmVMOperatingSystem -Windows -ComputerName "$vmName-0$i" `
                                                 -Credential $cred | `
                    Set-AzureRmVMSourceImage -PublisherName MicrosoftWindowsServer `
                                             -Offer WindowsServer `
                                             -Skus 2016-Datacenter `
                                             -Version latest |`
                    Add-AzureRmVMNetworkInterface -Id $nics[$i].id

        New-AzureRmVM -ResourceGroup $resourceGroup -Location $location -VM $vmConfig 
    }
    # Setting up IIS service
    for($i=1; $i -le $VMNumber; $i++){
    Set-AzureRmVMExtension -ResourceGroup "$resourceGroup" `
                           -ExtensionName "IIS" `
                           -VMName "$vmName-$i" `
                           -Location "$location" `
                           -Publisher "Microsoft.Compute" `
                           -ExtensionType CustomScriptExtension `
                           -asjob `
                           -TypeHandlerVersion 1.8 `
                           -SettingString '{"commandToExecute":"powershell Add-WindowsFeature Web-Server; powershell Add-Content -Path \"C:\\inetpub\\wwwroot\\Default.htm\" -Value $($env:computername)"}' `
    | Wait-Job | Receive-Job
    }
}
end{
    Get-AzureRmPublicIpAddress -ResourceGroup $resourceGroup | Select-Object -Property ipaddress
}
