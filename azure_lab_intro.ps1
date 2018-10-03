begin{
        # Variables
        $Size = "Standard_A2"
        $cred = Get-Credential -Message "Provide credential for VMs"
        # First group
        $rgEurope = "west-europe" 
        $rgFrance = "france-central"
        $AddressPrefixFrance = "10.0.1.0/24"


        # Second group
        $locEurope = "westeurope"
        $locFrance = "francecentral"
        $AddressPrefixEurope = "10.1.1.0/24"
        
        # Creating resource group
        New-AzureRmResourceGroup -Name $rgEurope -Location $locEurope
        New-AzureRmResourceGroup -Name $rgFrance -Location $locFrance

        #region VM create Function
        function create-VMwithResources {
            param(
                [Parameter(Mandatory=$true)]
                [String]$ResourceGroupName,
                
                [Parameter(Mandatory=$true)]
                [String]$Location,
                
                [Parameter(Mandatory=$true)]
                [string]$AddressPrefix
            )
            $vmParam = @{
                Name = "$ResourceGroupName-vm"
                VirtualNetworkName ="$ResourceGroupName-vnet"
                SubnetName  = "local-subnet"
                SecurityGroupName = "$ResourceGroupName-nsg" 
                OpenPorts = 80,3389
                Size = "Standard_A2"
            }
            
          new-azurermvm -ResourceGroupName $ResourceGroupName `
                        -location $location `
                        -AddressPrefix $AddressPrefix `
                        -Credential $cred `
                        @vmParam
        }
        #endregion VM
        
       
}
process{
        create-VMwithResources -ResourceGroupName $rgEurope -Location $locEurope -AddressPrefix $AddressPrefixEurope 
        create-VMwithResources -ResourceGroupName $rgFrance -Location $locFrance -AddressPrefix $AddressPrefixFrance
        
}
end{

}