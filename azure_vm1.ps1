# Connect-AzureRmAccount
<#
.SYNOPSIS
    azure_vm1.ps1
.DESCRIPTION
    azure_vm1.ps1 script will help you to deploy VM with loadBalancer
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

  param (
    [ValidateNotNullOrEmpty()]
    [Parameter(Mandatory=$true)]
    [string]$resourceGroup,
    
    [ValidateNotNullOrEmpty()]
    [Parameter(Mandatory=$true)]
    [string]$location,
    
    [ValidateNotNullOrEmpty()]
    [Parameter(Mandatory=$true)]
    [string]$vmSize,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [int]$vmNumber
)
    function nicAdapterCreate {
        [CmdletBinding()]
        param (
        
        )
            for($i=1; $i -le $vmNumber; $i++){
            # Create three virtual network cards and associate with public IP address and NSG.
             New-AzureRmNetworkInterface -ResourceGroupName $resourceGroup -Location $location `
            -Name "nicVM$i" -LoadBalancerBackendAddressPool $bepool -NetworkSecurityGroup $nsg `
            -Subnet $vnet.Subnets[0]
            }
        }
        
    function VmCreate {

            # Create an availability set.
            $as = New-AzureRmAvailabilitySet -ResourceGroupName $resourceGroup -Location $location `
            -Name 'MyAvailabilitySet' -Sku Aligned -PlatformFaultDomainCount 3 -PlatformUpdateDomainCount 3
        
            for ($i=1; $i -le $vmNumber; $i++){
        # Create a virtual machine configuration
        $vmConfig = New-AzureRmVMConfig -VMName "VM$i" -VMSize $vmSize -AvailabilitySetId $as.Id | `
        Set-AzureRmVMOperatingSystem -Windows -ComputerName 'myVM2' -Credential $cred | `
        Set-AzureRmVMSourceImage -PublisherName MicrosoftWindowsServer -Offer WindowsServer `
        -Skus 2016-Datacenter -Version latest  

        # Create a virtual machine
        New-AzureRmVM -ResourceGroupName $resourceGroup -Location $location -VM $vmConfig
            }
    }
          
# Create user object
$cred = Get-Credential -Message 'Enter a username and password for the virtual machine.'

# Create a resource group.
New-AzureRmResourceGroup -Name $resourceGroup -Location $location

# Create a virtual network.
$subnet = New-AzureRmVirtualNetworkSubnetConfig -Name 'MySubnet' -AddressPrefix 192.168.1.0/24

$vnet = New-AzureRmVirtualNetwork -ResourceGroupName $resourceGroup -Name 'MyVnet' `
  -AddressPrefix 192.168.0.0/16 -Location $location -Subnet $subnet

# Create a public IP address.
$publicIp = New-AzureRmPublicIpAddress -ResourceGroupName $resourceGroup -Name 'myPublicIP' `
  -Location $location -AllocationMethod Dynamic

# Create a front-end IP configuration for the website.
$feip = New-AzureRmLoadBalancerFrontendIpConfig -Name 'myFrontEndPool' -PublicIpAddress $publicIp

# Create the back-end address pool.
$bepool = New-AzureRmLoadBalancerBackendAddressPoolConfig -Name 'myBackEndPool'

# Creates a load balancer probe on port 80.
$probe = New-AzureRmLoadBalancerProbeConfig -Name 'myHealthProbe' -Protocol Http -Port 80 `
  -RequestPath / -IntervalInSeconds 360 -ProbeCount 5

# Creates a load balancer rule for port 80.
$rule = New-AzureRmLoadBalancerRuleConfig -Name 'myLoadBalancerRuleWeb' -Protocol Tcp `
  -Probe $probe -FrontendPort 80 -BackendPort 80 `
  -FrontendIpConfiguration $feip -BackendAddressPool $bePool

# Create a load balancer.
$lb = New-AzureRmLoadBalancer -ResourceGroupName $resourceGroup -Name 'MyLoadBalancer' -Location $location `
  -FrontendIpConfiguration $feip -BackendAddressPool $bepool `
  -Probe $probe -LoadBalancingRule $rule

# Create a network security group rule for port 3389.
$rule1 = New-AzureRmNetworkSecurityRuleConfig -Name 'myNetworkSecurityGroupRuleRDP' -Description 'Allow RDP' `
  -Access Allow -Protocol Tcp -Direction Inbound -Priority 1000 `
  -SourceAddressPrefix Internet -SourcePortRange * `
  -DestinationAddressPrefix * -DestinationPortRange 3389

# Create a network security group rule for port 80.
$rule2 = New-AzureRmNetworkSecurityRuleConfig -Name 'myNetworkSecurityGroupRuleHTTP' -Description 'Allow HTTP' `
  -Access Allow -Protocol Tcp -Direction Inbound -Priority 2000 `
  -SourceAddressPrefix Internet -SourcePortRange * `
  -DestinationAddressPrefix * -DestinationPortRange 80

# Create a network security group
$nsg = New-AzureRmNetworkSecurityGroup -ResourceGroupName $resourceGroup -Location $location `
-Name 'myNetworkSecurityGroup' -SecurityRules $rule1,$rule2
nicAdapterCreate
VmCreate
