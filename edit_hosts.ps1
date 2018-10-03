<#
.SYNOPSIS
    edit_hosts.ps1
.DESCRIPTION
    Use this function to add content in windows hosts.
.EXAMPLE
    PS C:\> edit_hosts.ps1 -resName git-lab.local -ipAddress 127.0.0.1
    This command will add 127.0.0.1     git-lab.local  note to hosts.
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$ResName,

    [Parameter(Mandatory=$true)]
    [string]$IpAddress
)
begin{
    #Requires -RunAsAdministrator
    $path = (Get-ChildItem Env:\windir).value + "\system32\drivers\etc\hosts"
}
process{
    try{

    Add-Content -Path $path -Value ("`n{0}`t`t`t{1}" -f $IpAddress, $ResName)

    }
    catch{

        Write-host "You should to have admin rights"
    }
}
end {
    Write-Host "`n`n"
    Get-Content -Path $path   
}
