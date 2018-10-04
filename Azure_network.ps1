<#
.SYNOPSIS
    azure_network.ps1
.DESCRIPTION
    Long description
.EXAMPLE
    PS C:\> <example usage>
    Explanation of what the example does
#>
begin {
    
    # VM admin credentials
    #$cred = Get-Credential -Message "Please input creddentials for vm admin"
    $sharedKeyVnet = 'Test123'

    
    # Network 1
    $virtNetPrefix1 = "10.1.0.0/16"
    $vmNetPrefix1 = "10.1.1.0/24"
    $gwPrefix1  = "10.1.2.0/27"
    $vpnClientPool1 = "10.1.3.0/24"

    # Network 2
    $virtNetPrefix2 = "10.2.0.0/16"
    $vmNetPrefix2  = "10.2.1.0/24"
    $gwPrefix2 = "10.2.2.0/27"
    $vpnClientPool2 = "10.2.3.0/24"

    # VMsize choosing
    $vmSize = 'Standard_A2'
  
    # Connect to Azure
    try {
        Write-host -ForegroundColor Green "Getting azure subscriptions"
        $subscription = Get-AzureRmSubscription
        Write-host -ForegroundColor Green "Selecting azure subscription with Id $($subscription.id)"
        Set-AzureRmContext -SubscriptionId $subscription.Id
    }
    catch {
        Connect-AzureRmAccount
    }

    # Create resource group
        New-AzureRmResourceGroup -Name "gomeltri" -Location "westeurope"
        New-AzureRmResourceGroup -Name "orshatri"  -Location "northeurope"



        # Create new storage account
        function Create-StorAccount {
            param(
               
                [Parameter(Mandatory = $true)]
                [String]$ResourceGroup,
            
                [Parameter(Mandatory = $true)]
                [String]$Location
                
            )
            if((Get-AzureRmStorageAccount -ResourceGroupName $ResourceGroup) -ne $null){
                Write-host "Storage account already exist"
            }
            else{
                Write-Host "Creating new storage account"
                New-AzureRmStorageAccount -Name ("{0}storage01" -f $ResourceGroup) `
                                                 -ResourceGroupName $resourceGroup `
                                                 -Location $location `
                                                 -SkuName Standard_GRS `
                                                 -Kind StorageV2 
            }
        }                                      
        function Create-NetSecGroup {
            param(
                
            [Parameter(Mandatory=$true)]
            [String]$ResourceGroup,

            [Parameter(Mandatory=$true)]
            [String]$location

            )
            # Defaults for rule 
            $secRuleVars = @{
                Access = 'Allow'
                Protocol = 'Tcp' 
                Direction = 'Inbound'
                SourceAddressPrefix = "*"
                SourcePortRange = "*"
                DestinationAddressPrefix = "*"
            }
            # Check for nsg exist and create if not
            if((Get-AzureRmNetworkSecurityGroup -ResourceGroupName $ResourceGroup) -ne $null){
                write-host ("Network security group already exist in {0} resource group" -f $ResourceGroup)
            }
            else {
                # Security rules RDP and HTTP
                $rule1 = New-AzureRmNetworkSecurityRuleConfig -Name 'RDP-Input' @secRuleVars -DestinationPortRange '3389' -Priority 100
                $rule2 = New-AzureRmNetworkSecurityRuleConfig -Name 'HTTP' @secRuleVars -DestinationPortRange '80' -Priority 101
                
                # Creating network security group
                Write-host ("Now we are creating new network security group in {0}" -f $ResourceGroup)
                New-AzureRmNetworkSecurityGroup -name ("{0}-nsg-01" -f $ResourceGroup) -ResourceGroupName $ResourceGroup -Location $location -SecurityRules $rule1, $rule2
            }
            
        }
        function Create-VMNetwork {

            param (

            [Parameter(Mandatory=$true)]
            [String]$ResourceGroup,

            [Parameter(Mandatory=$true)]
            [String]$location,

            [Parameter(Mandatory=$true)]
            [String]$IpPrefixVirtNet,

            [Parameter(Mandatory=$true)]
            [String]$IpPrefixVM

            )

            # Check an create virtual network and subnets
            if((Get-AzureRmVirtualNetwork -ResourceGroupName $ResourceGroup -ErrorAction SilentlyContinue) -ne $null){
                Write-Host "Virtual network already exist"
            }
            else{
               # $nsg = Get-AzureRmNetworkSecurityGroup -ResourceGroupName $ResourceGroup
                $vmSubnet = New-AzureRmVirtualNetworkSubnetConfig -Name ("{0}-vm-subnet" -f $ResourceGroup) -AddressPrefix $IpPrefixVM #-NetworkSecurityGroup $nsg
                New-AzureRmVirtualNetwork -Name ("{0}-vnet-01" -f $ResourceGroup) `
                                          -AddressPrefix $IpPrefixVirtNet `
                                          -Subnet $vmSubnet `
                                          -ResourceGroupName $ResourceGroup `
                                          -Location $location
            }
            
        }
        function Create-VnetGateway {
            param (
                
            [Parameter(Mandatory=$true)]
            [String]$ResourceGroup,

            [Parameter(Mandatory=$true)]
            [String]$location,

            [String]$IpPrefixGateway
            )
            $GwName = ("{0}-gateway" -f $ResourceGroup)

            # Check for gateway exist and create if not
            $gw = Get-AzureRmVirtualNetworkGateway -ResourceGroupName $ResourceGroup -name $GwName -ErrorAction SilentlyContinue
            if($gw -ne $null){
                Write-Host ("{0} gateway already exist" -f $GwName)
            }
            else {
            # Check for gateway subnet
            $virtNet = Get-AzureRmVirtualNetwork -ResourceGroupName $ResourceGroup
            $gwSubnet = Get-AzureRmVirtualNetworkSubnetConfig -VirtualNetwork $virtNet -Name "gatewaysubnet" -ErrorAction SilentlyContinue
                if($gwSubnet -ne $null){
                    Write-host "Gateway subnet already exist"
                }
                else {
                    Add-AzureRmVirtualNetworkSubnetConfig -Name "gatewaysubnet" -VirtualNetwork $virtNet -AddressPrefix $IpPrefixGateway
                    $virtNet | Set-AzureRmVirtualNetwork
                    $gwSubnet = (Get-AzureRmVirtualNetwork -ResourceGroupName $ResourceGroup).Subnets | Where-Object -Property name -eq "gatewaysubnet"
                }
                $gwPip = New-AzureRmPublicIpAddress -ResourceGroupName $ResourceGroup -Name ("{0}-gw-pip-01" -f $ResourceGroup) -location $location -AllocationMethod Dynamic
                $gwConfig = New-AzureRmVirtualNetworkGatewayIpConfig -Name $GwName -PublicIpAddress $GwPip -Subnet $gwSubnet
                New-AzureRmVirtualNetworkGateway -Name ("{0}-gateway" -f $ResourceGroup)`
                                                 -ResourceGroupName $ResourceGroup `
                                                 -Location $location `
                                                 -IpConfigurations $gwConfig `
                                                 -GatewayType Vpn `
                                                 -VpnType RouteBased `
                                                 -GatewaySku VpnGw1 `
                                                 -asjob
            }
            
        }
          # Function add Vnet connection to gateway 
          function new-VnetConnection {
            param(
                [Parameter(Mandatory=$true)]
                [String]$ResourceGroup,

                [Parameter(Mandatory=$true)]
                [String]$location,

                [Parameter(Mandatory=$true)]
                [String]$ConnectionDSTResGroup,

                [Parameter(Mandatory=$true)]
                [String]$SharedKey,
                
                [Parameter(Mandatory=$true)]
                [ValidateSet("ipsec","vnet2vnet","vpnclinet")]
                [String]$ConnectionType

            )
            get-job | wait-job
            # Check for gateways exist
            try {
                $gw1 = get-azurermvirtualnetworkgateway -ResourceGroupName $ResourceGroup
                $gw2 = get-azurermvirtualnetworkgateway -ResourceGroupName $ConnectionDSTResGroup
            }
            catch{
                Write-host "Gateways not founded"
            }
            if(($gw1 -ne $null) -and ($gw2 -ne $null)){
            
            New-AzureRmVirtualNetworkGatewayConnection -Name ("{0}-{1}-connection" -f $resourcegroup, $ConnectionDSTResGroup) `
                                                       -ResourceGroupName $ResourceGroup `
                                                       -location $location `
                                                       -VirtualNetworkGateway1 $gw1 `
                                                       -VirtualNetworkGateway2 $gw2 `
                                                       -SharedKey $SharedKey `
                                                       -ConnectionType $ConnectionType
            
            }
        }
        function  Create-NewVM {
            param (
                [Parameter(Mandatory=$true)]
                [String]$ResourceGroup,
                [String]$location,
                [String]$VMName,
                [String]$VMSize,
                [String]$AvailabilitySetId,
                [String]$VMNumber
            )
     
            for($i=1; $i -le $VMNumber; $i++){
                $nic = New-AzureRmNetworkInterface -ResourceGroup $resourceGroup `
                                                   -Location $location `
                                                   -Name ("{0}-nic-{1}" -f $VMName, $i) `
                                                   -Subnet  ((Get-AzureRmVirtualNetwork -ResourceGroupName $ResourceGroup).Subnets| Where-Object -Property name -eq ("{0}-vm-subnet" -f $ResourceGroup))

                $vmConfig = New-AzureRmVMConfig -VMName ("{0}-{1}-0{2}" -f $ResourceGroup, $VMName, $i) -VMSize $vmSize 

                $vmConfig | Set-AzureRmVMBootDiagnostics -ResourceGroupName $resourceGroup -Enable -StorageAccountName (Get-AzureRmStorageAccount -ResourceGroupName $ResourceGroup).StorageAccountName

                $vmConfig | Set-AzureRmVMOperatingSystem -Windows -ComputerName ("{0}-{1}-0{2}" -f $ResourceGroup, $VMName, $i) -Credential $cred

                $vmConfig |  Set-AzureRmVMSourceImage -PublisherName MicrosoftWindowsServer -Offer WindowsServer -Skus 2016-Datacenter -Version latest
                
                $vmConfig | Add-AzureRmVMNetworkInterface -Id $nic.id
        
                New-AzureRmVM -ResourceGroup $resourceGroup -Location $location -VM $vmConfig
            }
        }
        
    }
process {

   # create-StorAccount -ResourceGroup "gomeltri" -Location "westeurope"
   # create-StorAccount -ResourceGroup "orshatri" -Location "northeurope"

  # Create-NetSecGroup -ResourceGroup "gomeltri" -location "westeurope"
  # Create-NetSecGroup -ResourceGroup "orshatri" -location "northeurope"

    Create-VMNetwork -ResourceGroup "gomeltri" -location "westeurope" -IpPrefixVirtNet $virtNetPrefix1 -IpPrefixVM $vmNetPrefix1
    Create-VMNetwork -ResourceGroup "orshatri" -location "northeurope" -IpPrefixVirtNet $virtNetPrefix2 -IpPrefixVM $vmNetPrefix2

  #  Create-newVM -ResourceGroup "gomeltri" -location "westeurope" -VMName "web1" -$VMNumber 1
  #  Create-newVM -ResourceGroup "orshatri" -location "northeurope" -VMName "web1" -$VMNumber 1
    

    Create-VnetGateway -ResourceGroup "gomeltri" -location "westeurope" -IpPrefixGateway  $gwPrefix1
    Create-VnetGateway -ResourceGroup "orshatri" -location "northeurope" -IpPrefixGateway  $gwPrefix2

    new-VnetConnection -ResourceGroup "gomeltri" -location "westeurope" -ConnectionDSTResGroup "orshatri" -SharedKey $sharedKeyVnet -ConnectionType "vnet2vnet"
    new-VnetConnection -ResourceGroup "orshatri" -location "northeurope" -ConnectionDSTResGroup "gomeltri" -SharedKey $sharedKeyVnet -ConnectionType "vnet2vnet"

    
}
end {
    
}