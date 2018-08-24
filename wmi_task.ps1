$inputStatus = $false

function getWmiDevices {
    $devCount = Get-CimInstance -ClassName CIM_USBDevice | Measure-Object
    return $devCount
}
Write-Host "Please instert usb"
do {
    $currentDevNumber = $devNumb
    $devNumb = getWmiDevices
    if ($currentDevNumber.Count -lt $devNumb.Count -and $currentDevNumber.Count -ne 0) {
        Write-Host "Usb device was inserted"
        $inputStatus = $true
    }
   
    else {
        if ($currentDevNumber.Count -gt $devNumb.Count) {
            Write-Host "Usb device was ejected"
            
        }
        Write-host "Check current devices for new device"
        for ($i = 5 ; $i -ge 1 ; $i--) {
            Write-Host $i
            Start-Sleep 1
        }
                     
    }
    
    
    
    
} while ($inputStatus -ne $true)

