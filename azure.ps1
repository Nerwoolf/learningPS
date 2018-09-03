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
    [Parameter(Mandatory=$true)]
    [String]$resourceGroup,

    [Parameter(Mandatory=$true)]
    [String]$location
)
begin{
    $cred = Get-Credential -Message "Credentials for VM admin account"
    try {
        Get-AzureRmSubscription
    }
    catch {
        Connect-AzureRmAccount
    }
}
process{
    $nsg = New-AzureRmNetworkSecurityGroup -Name "NSG" -ResourceGroupName $resourceGroup -Location $location `
    -SecurityRules $rdprule, $httprule -
    $natrule1 = New-AzureRmLoadBalancerInboundNatRuleConfig
    $natrule2 = 
    $rdprule = New-AzureRmNetworkSecurityRuleConfig -Name rdp-rule -Description "Allow RDP" -Access Allow `
    -Protocol Tcp -Direction Inbound -Priority 100 -SourceAddressPrefix Internet -SourcePortRange * `
    -DestinationAddressPrefix * -DestinationPortRange 3389
    $httprule = New-AzureRmNetworkSecurityRuleConfig -Name HTTP -Description "Allow HTTP" -Access Allow `
    -Protocol Tcp -Direction Inbound -Priority 100 -SourceAddressPrefix Internet -SourcePortRange * `
    -DestinationAddressPrefix * -DestinationPortRange 80
    $subnet = New-AzureRmVirtualNetworkSubnetConfig -Name "LocSub" -AddressPrefix "192.168.1.0/24" -NetworkSecurityGroup $nsg
    $virtNet = New-AzureRmVirtualNetwork -Name "VirtNet" -ResourceGroupName $resourceGroup -Location $location `
    -AddressPrefix "192.168.0.0/16" -Subnet $subnet
    
    $loadBalancer = New-AzureRmLoadBalancer -Name "LB" -ResourceGroupName $resourceGroup -Location $location `
    -FrontendIpConfiguration $FEpool -BackendAddressPool $BEpool -Probe $probe -LoadBalancingRule $loadBalRul
    $loadBalRul = New-AzureRmLoadBalancerRuleConfig -Name "LBRule" -FrontendIpConfigurationId -BackendAddressPoolId -Protocol HTTP `
    -ProbeId $probe.id
    $probe = New-AzureRmLoadBalancerProbeConfig -Name "HTTP-probe" -Port 80 -Protocol Http -IntervalInSeconds 20 -ProbeCount 5 
    $publicIP = New-AzureRmPublicIpAddress -Name "PubIp" -ResourceGroupName $resourceGroup -Location $location `
    -AllocationMethod Dynamic
    $FEpool = New-AzureRmLoadBalancerFrontendIpConfig -Name "FEipPool" -PublicIpAddress $publicIP
    $BEpool = New-AzureRmLoadBalancerBackendAddressPoolConfig -Name "BEPool"
    $nic1 = new-azurerm
    $vm 

}
end{

}