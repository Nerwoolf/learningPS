#Requires -RunAsAdministrator
<#
.SYNOPSIS
    applock.ps1
.DESCRIPTION
    This script import exported applocker xml policy file, update group policies and restart PC.
    Settings will be applied after PC reboot.
.EXAMPLE
    PS C:\>applock.ps1
#>
# Export your ready APPLockerPolicy to folder with this script. Use name like "policy.xml"

$XMLPath ="`.\policy.xml"
#----------------------------------------------------------------------------------------
$Error.Clear()
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
$message = Write-host -ForegroundColor Yellow  "Please export you applocker settings to desktop and provide file name to this input"
try{
        
        Write-Host -ForegroundColor Green "Try to import policy..."
        Set-AppLockerPolicy -XmlPolicy $XMLPath -ErrorAction SilentlyContinue
        if($?){
            Write-Host -ForegroundColor Green "Policy was imported successfully"
        } 
        Write-Host -ForegroundColor Green "Change startup type AppIDSvc service."
        Get-Service AppIDSvc | Set-Service -StartupType Automatic -ErrorAction SilentlyContinue
        Write-Host -ForegroundColor Green "Updating group policy..."
        gpupdate /force 
        Write-Host -ForegroundColor Green "Do you want to restart PC"
        $restartPC = Read-Host "Y or N"
        switch ($restartPC) {
            "y" {Restart-Computer -Force}
            Default {"Script was done"}
        }
        start-sleep 2
        exit
}
    
Catch{
  $Error 
}



