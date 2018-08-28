$query = "SELECT * FROM CIM_InstModification WHERE TargetInstance ISA 'Win32_LocalTime'"
Register-CimIndicationEvent -Query $query -SourceIdentifier "Timer"


#$action = {$name = $event.SourceEventArgs.NewEvent.ProcessName; $id = $event.SourceEventArgs.NewEvent.ProcessId; Write-Host –Object "New Process Started : Name = $name; ID = $id"}
    
    
    
#Register-CimIndicationEvent -ClassName 'Win32_ProcessStartTrace' -SourceIdentifier "ProcessStarted" -Action $action
    