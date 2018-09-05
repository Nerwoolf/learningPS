<#
.SYNOPSIS
    azure_network.ps1
.DESCRIPTION
    Long description
.EXAMPLE
    PS C:\> <example usage>
    Explanation of what the example does
#>
param(
    [Parameter(Mandatory = $true)]
    [String]$resourceGroup,

    [Parameter(Mandatory = $true)]
    [String]$location
    
    
              
)
begin {
    
    # VM admin credentials
    $cred = Get-Credential -Message "Please input creddentials for vm admin"
    $sharedKeyVnet = 'Test123'
    $vmNumber = "1"
    $vmName = $resourceGroup+"web"
    $vmSize = "Standard_A2"
    # $VNet1       = "VNet1"
    $GwSubnet1 = "GatewaySubnet"
    $VNet1Prefix = "10.1.0.0/16"
    # $FEPrefix1   = "10.1.0.0/24"
    $BEPrefix1 = "10.1.1.0/24"
    $GwPrefix1 = "10.1.255.0/27"
    # $VNet1ASN    = 65010
    # $DNS1        = "8.8.8.8"
    # $Gw1         = "VNet1GW"
    # $GwIP1       = "VNet1GWIP"
    # $GwIPConf1   = "gwipconf1"

    # Security rules
    $secRuleVars = @{
        Access                   = 'Allow'
        Protocol                 = 'Tcp' 
        Direction                = 'Inbound'
        SourceAddressPrefix      = "*"
        SourcePortRange          = "*"
        DestinationAddressPrefix = "*"
    }

    
        # Create new storage account
        $storAccount = New-AzureRmStorageAccount -Name "$resourceGroup`storage01" `
                                                 -ResourceGroupName $resourceGroup `
                                                 -Location $location `
                                                 -SkuName Standard_GRS `
                                                 -Kind StorageV2 

}
process {
    
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

    # Create NetworkSecurity group 
    $nsg = New-AzureRmNetworkSecurityGroup -Name "$resourceGroup-nsg-01" `
        -ResourceGroup $resourceGroup `
        -Location $location `
        -SecurityRules $rule1, $rule2
   
    # Add subnets to virtual network
    $GwSubnet = new-AzureRmVirtualNetworkSubnetConfig -Name $GwSubnet1 `
        -AddressPrefix $GwPrefix1 -NetworkSecurityGroup $nsg
    
    $vmSubnet = new-AzureRmVirtualNetworkSubnetConfig -Name "$resourceGroup-subnet-01" `
        -AddressPrefix $BEPrefix1 -NetworkSecurityGroup $nsg

    # Create virtual network
    $virtNet = New-AzureRmVirtualNetwork -Name "$resourceGroup-vnet-01" `
                                         -AddressPrefix $VNet1Prefix `
                                         -ResourceGroupName $resourceGroup `
                                         -Location $location `
                                         -Subnet $vmSubnet, $GwSubnet
   
    # Create public ip
    $pubIp = New-AzureRmPublicIpAddress -Name "$resourceGroup-pip-01" `
        -ResourceGroupName $resourceGroup `
        -Location $location `
        -AllocationMethod Dynamic
    

    # Create ipconfiguration for Virtual Gateway
    $vnGWconfig = New-AzureRmVirtualNetworkGatewayIpConfig -Name "$resourceGroup-vngwconfig" `
        -PublicIpAddress $pubIp `
        -Subnet $virtNet.Subnets[0]

    # Create Virtual Network Gateway
    $vnGW = New-AzureRmVirtualNetworkGateway -Name "$resourceGroup-vngateway-01" `
        -ResourceGroupName $resourceGroup `
        -Location $location `
        -IpConfigurations $vnGWconfig `
        -GatewayType Vpn `
        -VpnType RouteBased `
        -GatewaySku Basic
    
    # Create vnet connection
    $vnetgwBrest = Get-AzureRmVirtualNetworkGateway -ResourceGroupName "brest"
    $vnetgwMinsk = Get-AzureRmVirtualNetworkGateway -ResourceGroupName "Minsk"
    $vnetConnect = New-AzureRmVirtualNetworkGatewayConnection -Name "$resourceGroup-minsk-connect" `
                                                              -VirtualNetworkGateway1 $vnetgwBrest `
                                                              -VirtualNetworkGateway2 $vnetgwMinsk `
                                                              -ResourceGroupName $resourceGroup `
                                                              -Location $location `
                                                              -sharedkey $sharedKeyVnet `
                                                              -ConnectionType Vnet2Vnet
  # Create network adapters
  $nics = @{} 
    
  for($i=1; $i -le $VMNumber; $i++){
      #-NetworkSecurityGroup $nsg `
      $nics[$i] = New-AzureRmNetworkInterface -ResourceGroup $resourceGroup `
                                              -Location $location `
                                              -Name "$vmName-$i-nic" `
                                              -Subnet $virtNet.Subnets[1]
                            
  }
    
    # Create VM with configuring
    for($i=1; $i -le $VMNumber; $i++){
    
        $vmConfig = New-AzureRmVMConfig -VMName "$vmName-$i" `
                                        -VMSize $vmSize `
                                        -AvailabilitySetId $availSet.Id | ` 
                    Set-AzureRmVMBootDiagnostics -ResourceGroupName $resourceGroup `
                                                 -Enable `
                                                 -StorageAccountName $storAccount.StorageAccountName |`
                    Set-AzureRmVMOperatingSystem -Windows -ComputerName "$vmName-0$i" `
                                                 -Credential $cred | `
                    Set-AzureRmVMSourceImage -PublisherName MicrosoftWindowsServer `
                                             -Offer WindowsServer `
                                             -Skus 2016-Datacenter `
                                             -Version latest |`
                    Add-AzureRmVMNetworkInterface -Id $nics[$i].id

        New-AzureRmVM -ResourceGroup $resourceGroup -Location $location -VM $vmConfig 
    }
}
end {
    add-newazurermvirtualnetrowksubnetconfig 
}