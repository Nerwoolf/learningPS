param (

    [Parameter(Mandatory=$true)]
    [String]$location,

    [Parameter(Mandatory=$true)]
    [String]$resourceGroup,

    [Parameter(Mandatory=$true)]
    [int]$vmNumber

    

)
begin{
        # VM config
        $configVM = @{
             ResourceGroupName = "$resourceGroup"
             location ="$location"
             VirtualNetworkName = "CRG-Vnet"
             AddressPrefix = "192.168.0.0/16"
             SubnetName = "CRG-Subnet"
             SecurityGroupName = "CRG-NSG"
             OpenPorts = "80,3389"
             AvailabilitySetName = "$availSet"
        }
        function CreateVM {
            for($i=0; $i -lt $vmNumber; $i++)
            {
                new-azurermVM -name "VM$i" @configVM -asjob
            }
        
            
        }
    #Connect to azure account
        Connect-AzureRmAccount
       # get cred for VM 
        $cred = Get-Credential -Message "Please write cred for VM user"
        
        # Create ResourceGroup
        New-AzureRmResourceGroup -Name $resourceGroup -Location $location
    
}
process{

    # Create availibility set

    $availSet =  New-AzureRmAvailabilitySet 
    -Location "$location" `
    -Name "myAvailabilitySet" `
    -ResourceGroupName "$resourceGroup"
    -Sku aligned `
    -PlatformFaultDomainCount 2 `
    -PlatformUpdateDomainCount 2
    # Creating VM 
    CreateVM

}
end{

}
