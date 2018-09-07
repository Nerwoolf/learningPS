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
    [String]$resourceGroup1='paris',

    [Parameter(Mandatory = $true)]
    [String]$resourceGroup2='moscow',

    [Parameter(Mandatory = $true)]
    [String]$location1='WestEurope',

    [Parameter(Mandatory = $true)]
    [String]$location2='WestEurope'
    
    
              
)
begin {
    
    # VM admin credentials
    $cred = Get-Credential -Message "Please input creddentials for vm admin"
    $sharedKeyVnet = 'Test123'
    $vmNumber = "1"
    $vmName1 = $resourceGroup1+"web"
    $vmName2 = $resourceGroup2+"web"
    
    # Network 1
    $gwPrefix1  = "10.1.1.0/26"
    $vmNetPrefix1 = "10.1.1.128/26"
    $virtNetPrefix1 = "10.1.1.0/24"
    $vpnClientPool1 = "10.1.5.0.24"

    # Network 2
    $vmNetPrefix2  = "10.1.2.0/26"
    $gwPrefix2 = "10.1.2.128/26"
    $virtNetPrefix2 = "10.1.2.0/24"
    $vpnClientPool2 = "10.1.3.0.24"

    # VMsize choosing
    $vmSize = 'Standard_A2'


    # Security rules
    $secRuleVars = @{
        Access                   = 'Allow'
        Protocol                 = 'Tcp' 
        Direction                = 'Inbound'
        SourceAddressPrefix      = "*"
        SourcePortRange          = "*"
        DestinationAddressPrefix = "*"
    }
    
    # Connect to Azure
    try {
        Get-AzureRmSubscription
    }
    catch {
        Connect-AzureRmAccount
    }

    # Create resource group
        New-AzureRmResourceGroup -Name $resourceGroup1 -Location $location1
        New-AzureRmResourceGroup -Name $resourceGroup2 -Location $location2


    
        # Create new storage account
        $storAccount1 = New-AzureRmStorageAccount -Name "$resourceGroup1`storage01" `
                                                 -ResourceGroupName $resourceGroup1 `
                                                 -Location $location1 `
                                                 -SkuName Standard_GRS `
                                                 -Kind StorageV2 
        $storAccount2 = New-AzureRmStorageAccount -Name "$resourceGroup2`storage02" `
                                                 -ResourceGroupName $resourceGroup2 `
                                                 -Location $location2 `
                                                 -SkuName Standard_GRS `
                                                 -Kind StorageV2 

}
process {
    
     # Create Availbility set
        $availSet1 = New-AzureRmAvailabilitySet -ResourceGroup $resourceGroup1 `
        -Location $location1 `
        -name "$resourceGroup1-availset-01" `
        -PlatformUpdateDomainCount 2 `
        -PlatformFaultDomainCount 2 `
        -Sku Aligned

        $availSet2 = New-AzureRmAvailabilitySet -ResourceGroup $resourceGroup2 `
        -Location $location2 `
        -name "$resourceGroup2-availset-02" `
        -PlatformUpdateDomainCount 2 `
        -PlatformFaultDomainCount 2 `
        -Sku Aligned

    # Create NSG Rules 
    $rule1 = New-AzureRmNetworkSecurityRuleConfig -Name 'RDP-Allow' @secRuleVars -Priority 100 -DestinationPortRange 3389
    $rule2 = New-AzureRmNetworkSecurityRuleConfig -Name 'HTTP-Allow' @secRuleVars -Priority 101 -DestinationPortRange 80

    # Create NetworkSecurity group 
    $nsg1 = New-AzureRmNetworkSecurityGroup -Name "$resourceGroup1-nsg-01" `
        -ResourceGroup $resourceGroup1 `
        -Location $location1 `
        -SecurityRules $rule1, $rule2

    $nsg2 = New-AzureRmNetworkSecurityGroup -Name "$resourceGroup2-nsg-02" `
        -ResourceGroup $resourceGroup2 `
        -Location $location2 `
        -SecurityRules $rule1, $rule2
   
    # Add VM and Gateway subnets to virtual network
    $GwSubnet1 = new-AzureRmVirtualNetworkSubnetConfig -Name "gatewaysubnet" `
        -AddressPrefix $GwPrefix1 -NetworkSecurityGroup $nsg1
    
    $vmSubnet1 = new-AzureRmVirtualNetworkSubnetConfig -Name "$resourceGroup1-subnet-01" `
        -AddressPrefix $vmNetPrefix1 -NetworkSecurityGroup $nsg1

    $GwSubnet2 = new-AzureRmVirtualNetworkSubnetConfig -Name "gatewaysubnet" `
        -AddressPrefix $GwPrefix2 -NetworkSecurityGroup $nsg2
    
    $vmSubnet2 = new-AzureRmVirtualNetworkSubnetConfig -Name "$resourceGroup2-subnet-02" `
        -AddressPrefix $vmNetPrefix2 -NetworkSecurityGroup $nsg2
      

    # Create virtual network
    $virtNet1 = New-AzureRmVirtualNetwork -Name "$resourceGroup1-vnet-01" `
                                         -AddressPrefix $virtNetPrefix1 `
                                         -ResourceGroupName $resourceGroup1 `
                                         -Location $location1 `
                                         -Subnet $vmSubnet1, $GwSubnet1

    $virtNet2 = New-AzureRmVirtualNetwork -Name "$resourceGroup2-vnet-02" `
                                         -AddressPrefix $virtNetPrefix2 `
                                         -ResourceGroupName $resourceGroup2 `
                                         -Location $location2 `
                                         -Subnet $vmSubnet2, $GwSubnet2
   
    # Create public ip
    $pubIp1 = New-AzureRmPublicIpAddress -Name "$resourceGroup1-pip-01" `
        -ResourceGroupName $resourceGroup1 `
        -Location $location1 `
        -AllocationMethod Dynamic

    $pubIp2 = New-AzureRmPublicIpAddress -Name "$resourceGroup2-pip-01" `
        -ResourceGroupName $resourceGroup2 `
        -Location $location2 `
        -AllocationMethod Dynamic
    

    # Create ipconfiguration for Virtual Gateway
    $vnGWconfig1 = New-AzureRmVirtualNetworkGatewayIpConfig -Name "$resourceGroup1-vngwconfig" `
        -PublicIpAddress $pubIp1 `
        -Subnet (Get-AzureRmVirtualNetworkSubnetConfig -VirtualNetwork $virtNet1 | Where-Object -Property Name -eq "gatewaysubnet")

    $vnGWconfig2 = New-AzureRmVirtualNetworkGatewayIpConfig -Name "$resourceGroup2-vngwconfig" `
        -PublicIpAddress $pubIp2 `
        -Subnet (Get-AzureRmVirtualNetworkSubnetConfig -VirtualNetwork $virtNet2 | Where-Object -Property Name -eq "gatewaysubnet")

    # Create Virtual Network Gateway
    $vnGW1 = New-AzureRmVirtualNetworkGateway -Name "$resourceGroup1-gateway-01" `
        -ResourceGroupName $resourceGroup1 `
        -Location $location1 `
        -IpConfigurations $vnGWconfig1 `
        -GatewayType Vpn `
        -VpnType RouteBased `
        -GatewaySku Basic `
        -AsJob

    $vnGW2 = New-AzureRmVirtualNetworkGateway -Name "$resourceGroup2-gateway-01" `
        -ResourceGroupName $resourceGroup2 `
        -Location $location2 `
        -IpConfigurations $vnGWconfig2 `
        -GatewayType Vpn `
        -VpnType RouteBased `
        -GatewaySku Basic `
        -AsJob
    
    # Create vnet connection
    $vnetConnect1 = New-AzureRmVirtualNetworkGatewayConnection -Name "$resourceGroup1-$resourceGroup2-connect" `
                                                              -VirtualNetworkGateway1 $vnGW1 `
                                                              -VirtualNetworkGateway2 $vnGW2 `
                                                              -ResourceGroupName $resourceGroup1 `
                                                              -Location $location1 `
                                                              -sharedkey $sharedKeyVnet `
                                                              -ConnectionType Vnet2Vnet
    $vnetConnect2 = New-AzureRmVirtualNetworkGatewayConnection -Name "$resourceGroup2-$resourceGroup1-connect" `
                                                              -VirtualNetworkGateway1 $vnGW2 `
                                                              -VirtualNetworkGateway2 $vnGW1 `
                                                              -ResourceGroupName $resourceGroup2 `
                                                              -Location $location2 `
                                                              -sharedkey $sharedKeyVnet `
                                                              -ConnectionType Vnet2Vnet

    # Generate new certificate 
    $cert = New-SelfSignedCertificate -Type Custom -KeySpec Signature `
                                      -Subject "CN=P2SRootCert" -KeyExportPolicy Exportable `
                                      -HashAlgorithm sha256 -KeyLength 2048 `
                                      -CertStoreLocation "Cert:\CurrentUser\My" -KeyUsageProperty Sign -KeyUsage CertSign
    New-SelfSignedCertificate -Type Custom -DnsName P2SChildCert -KeySpec Signature `
                                      -Subject "CN=P2SChildCert" -KeyExportPolicy Exportable `
                                      -HashAlgorithm sha256 -KeyLength 2048 `
                                      -CertStoreLocation "Cert:\CurrentUser\My" `
                                      -Signer $cert -TextExtension @("2.5.29.37={text}1.3.6.1.5.5.7.3.2")

    # Set pool for VPN
    Set-AzureRmVirtualNetworkGatewayVpnClientConfig -VirtualNetworkGateway $vnGW1 -VpnClientAddressPool "192.168.20.0/24"
  # Create network adapters
  $nics = @{} 
    
  for($i=1; $i -le $VMNumber; $i++){
      #-NetworkSecurityGroup $nsg `
      $nics[$i] = New-AzureRmNetworkInterface -ResourceGroup $resourceGroup1 `
                                              -Location $location1 `
                                              -Name "$vmName-$i-nic" `
                                              -Subnet $virtNet.Subnets[1]
                            
  }
    
    # Create VM with configuring
    for($i=1; $i -le $VMNumber; $i++){
    
        $vmConfig = New-AzureRmVMConfig -VMName "$vmName-$i" `
                                        -VMSize $vmSize `
                                        -AvailabilitySetId $availSet.Id | ` 
                    Set-AzureRmVMBootDiagnostics -ResourceGroupName $resourceGroup1 `
                                                 -Enable `
                                                 -StorageAccountName $storAccount.StorageAccountName |`
                    Set-AzureRmVMOperatingSystem -Windows -ComputerName "$vmName-0$i" `
                                                 -Credential $cred | `
                    Set-AzureRmVMSourceImage -PublisherName MicrosoftWindowsServer `
                                             -Offer WindowsServer `
                                             -Skus 2016-Datacenter `
                                             -Version latest |`
                    Add-AzureRmVMNetworkInterface -Id $nics[$i].id

        New-AzureRmVM -ResourceGroup $resourceGroup1 -Location $location1 -VM $vmConfig 
    }
}
end {
    add-newazurermvirtualnetrowksubnetconfig 
}