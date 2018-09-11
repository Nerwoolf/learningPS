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
   # [Parameter(Mandatory = $true)]
   # [String]$ResourceGroup1='paris',

    [Parameter(Mandatory = $true)]
    [String]$location='WestEurope'
       
)
begin {
    
    # VM admin credentials
    $cred = Get-Credential -Message "Please input creddentials for vm admin"
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
        Get-AzureRmSubscription
    }
    catch {
        Connect-AzureRmAccount
    }

    # Create resource group
        New-AzureRmResourceGroup -Name "moscow" -Location $location
        New-AzureRmResourceGroup -Name "paris"  -Location $location



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
                $nsg = Get-AzureRmNetworkSecurityGroup -ResourceGroupName $ResourceGroup
                $vmSubnet = New-AzureRmVirtualNetworkSubnetConfig -Name ("{0}-vm-subnet" -f $ResourceGroup) -AddressPrefix $IpPrefixVM -NetworkSecurityGroup $nsg
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
                    $gwSubnet = Add-AzureRmVirtualNetworkSubnetConfig -Name "gatewaysubnet" -VirtualNetwork $virtNet -AddressPrefix $IpPrefixGateway
                    $virtNet | Set-AzureRmVirtualNetwork
                }
                $gwPip = New-AzureRmPublicIpAddress -ResourceGroupName $ResourceGroup -Name ("{0}-gw-pip-01" -f $ResourceGroup) -AllocationMethod Dynamic -Location  $location
                $gwConfig = New-AzureRmVirtualNetworkGatewayIpConfig -Name $GwName -PublicIpAddress $GwPip -Subnet $gwSubnet
                New-AzureRmVirtualNetworkGateway -Name ("{0}-gateway" -f $ResourceGroup)`
                                                 -ResourceGroupName $ResourceGroup `
                                                 -Location $location `
                                                 -IpConfigurations $gwConfig `
                                                 -GatewayType Vpn `
                                                 -VpnType RouteBased `
                                                 -GatewaySku VpnGw1
            }
            
        }
        function  Create-azureRmVM {
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

    create-StorAccount -ResourceGroup "moscow" -Location $location
    create-StorAccount -ResourceGroup "paris" -Location $location

    Create-NetSecGroup -ResourceGroup "moscow" -location $location
    Create-NetSecGroup -ResourceGroup "paris" -location $location

    Create-VMNetwork -ResourceGroup "moscow" -location $location -IpPrefixVirtNet $virtNetPrefix1 -IpPrefixVM $vmNetPrefix1
    Create-VMNetwork -ResourceGroup "paris" -location $location -IpPrefixVirtNet $virtNetPrefix2 -IpPrefixVM $vmNetPrefix2

    Create-VnetGateway -ResourceGroup "moscow" -location $location -IpPrefixGateway $gwPrefix1
    Create-VnetGateway -ResourceGroup "paris" -location $location -IpPrefixGateway $gwPrefix2





                                 
   
   #>     
   <# # Generate new certificate 
    $cert = New-SelfSignedCertificate -Type Custom -KeySpec Signature `
                                      -Subject "CN=P2SRootCert" -KeyExportPolicy Exportable `
                                      -HashAlgorithm sha256 -KeyLength 2048 `
                                      -CertStoreLocation "Cert:\CurrentUser\My" -KeyUsageProperty Sign -KeyUsage CertSign
    New-SelfSignedCertificate -Type Custom -DnsName P2SChildCert -KeySpec Signature `
                                      -Subject "CN=P2SChildCert" -KeyExportPolicy Exportable `
                                      -HashAlgorithm sha256 -KeyLength 2048 `
                                      -CertStoreLocation "Cert:\CurrentUser\My" `
                                      -Signer $cert -TextExtension @("2.5.29.37={text}1.3.6.1.5.5.7.3.2")
    #>

}
end {
    
}