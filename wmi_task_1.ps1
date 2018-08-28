$Query = "select * from __InstanceCreationEvent within 5 where TargetInstance ISA 'Win32_LogicalDisk' and TargetInstance.DriveType = 2"
$message = "USB was inserted"
Register-WmiEvent -Query $Query -Action {
    Write-Output $message
}