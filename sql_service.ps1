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
function new-sqlservice {
    param(
        [Parameter(Mandatory=$true)]
        [String]$ResGroup,

        [Parameter(Mandatory=$true)]
        [String]$Location,

        [Parameter(Mandatory=$true)]
        [String]$ServerName

        

    )
begin{
        New-AzureRmResourceGroup -Name $ResGroup -Location $Location
        $cred = Get-Credential -Message "Please input user name and password for server admin"
}
process{
    

    New-AzureRmSqlServer -ResourceGroupName $ResGroup -Location $Location -ServerName $ServerName -SqlAdministratorCredentials $cred
}
end{

}
}
new-sqlservice -ResGroup "Minsk" -ServerName "sqltest" -Location "westeurope"

