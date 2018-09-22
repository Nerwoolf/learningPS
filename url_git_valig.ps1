<#
.SYNOPSIS
    url_git_valid.ps1
.DESCRIPTION
    Validate git path
.EXAMPLE
    PS C:\> url_git_valid.ps1 -branchname refs/heads/FB/11.1/DBAUtil_Changes
#>

$reg = "^/?(\w+[-._/]?){1,}(\w+[-._/]?){0,1}$"
function check-branchname {
param(
[parameter(Mandatory=$true)]
[String]$BranchUrl
)  
$BranchUrl = $BranchUrl.Trim('')
$Error.Clear()
if($BranchUrl.Contains(' ')){
Write-error "Contain spaces" -ErrorAction Stop
}
try{
if($BranchUrl -match $reg){
   return $true
}
else{
    return $false
}
}
catch{
    return $Error
}
}