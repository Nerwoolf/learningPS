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
    $sharedKeyVnet = '2wsx3edC'

    #region Variables network one
    $virtNetPrefix1 = "10.1.0.0/16"
    $vmNetPrefix1 = "10.1.1.0/24"
    $gwPrefix1  = "10.1.2.0/27"
    $vpnClientPool1 = "10.1.3.0/24"
    #endregion
    #region Variables network two
    $virtNetPrefix2 = "10.2.0.0/16"
    $vmNetPrefix2  = "10.2.1.0/24"
    $gwPrefix2 = "10.2.2.0/27"
    $vpnClientPool2 = "10.2.3.0/24"
    $vmSize = 'Standard_A2'
    #endregion

    # Setting for IIS
    $iisSettings = @{
  #  "commandToExecute"="powershell Add-WindowsFeature Web-Server; powershell Add-Content -Path \"C:\\inetpub\\wwwroot\\Default.htm\" -Value $($env:computername)"
    }
    # VMsize choosing
  #  
  
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

        # Function to create new storage account
        function new-StorAccount {
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

        # This function creating security group                                     
        function new-NetSecGroup {
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

        # Function to create virtual network
        function new-VMNetwork {
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
        
        # Function to create virtual network Gateway
        function new-VnetGateway {
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

        # This function create VM with network interface and add it to network security group 
        function  new-azureVMdeploy {
            param (
                [Parameter(Mandatory=$true)]
                [String]$ResourceGroup,

                [Parameter(Mandatory=$true)]
                [String]$location,

                [Parameter(Mandatory=$true)]
                [String]$VMName,

                [Parameter(Mandatory=$true)]
                [String]$VMSize,

                [String]$AvailabilitySetId,

                [Parameter(Mandatory=$true)]
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
        
        # Use this function to send command in guest OS of your VM
        function invoke-VMScript {
            param (
                [Parameter(Mandatory=$true)]
                [String[]]$Computername
                
            )
        for($i=1; $i -le $VMNumber; $i++){
            Set-AzureRmVMExtension -ResourceGroup "$resourceGroup" `
                                   -ExtensionName "IIS" `
                                   -VMName "$vmName-$i" `
                                   -Location "$location" `
                                   -Publisher "Microsoft.Compute" `
                                   -ExtensionType CustomScriptExtension `
                                   -asjob `
                                   -TypeHandlerVersion 1.8 `
                                   -SettingString '"commandToExecute"="powershell Add-WindowsFeature Web-Server; powershell Add-Content -Path \"C:\\inetpub\\wwwroot\\Default.htm\" -Value $($env:computername)"'

        }
        }
        
        # Add rule to network security group
         function add-securityRule{
            param (
                [Parameter(Mandatory=$true)]
                [String]$Name,
                
                [Parameter(Mandatory=$true)]
                [String]$ResourceGroupName,
                
                [Parameter(Mandatory=$true)]
                [ValidateSet("allow","deny")]
                [String]$Access,
                
                [Parameter(Mandatory=$true)]
                [String]$DestinationPortRange,

                [Parameter(Mandatory=$true)]
                [int]$Priority
                               
            )
            $secRuleVars = @{
                Protocol = 'Tcp' 
                Direction = 'Inbound'
                SourceAddressPrefix = "*"
                SourcePortRange = "*"
                DestinationAddressPrefix = "*"
            }
            $PSBoundParameters.remove("ResourceGroupName") | out-null
           $nsg = Get-AzureRmNetworkSecurityGroup -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue
            if($nsg -ne $null){
                Add-AzureRmNetworkSecurityRuleConfig -NetworkSecurityGroup $nsg @PSBoundParameters @secRuleVars 
                Set-AzureRmNetworkSecurityGroup -NetworkSecurityGroup $nsg
            }
            else {
                Write-host ("Security group doesn't exist in {0} resource group" -f $ResourceGroupName)
            }
        }
}
process {            


}
end {

}
