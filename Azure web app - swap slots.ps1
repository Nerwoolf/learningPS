$resourceGroup = $AzureResourceGroupName
$slotName = $AzureSlotName
$webAppName = $AzureWebAppName
$siteUrl = $url
# for local testing
$resourceGroup = "nerwoolf-webapp"
$slotName = "deploymentslot2"
$webAppName = "nerwoolf-webapp"
$siteUrl = "http://nerwoolf-webapp.azurewebsites.net"
Write-Host ("Start azure web app deployment slot swap.")
Write-Host (" -slot name = {0}`n -web app = {1}`n -site url = {2}`n`n" -f $slotName, $webAppName, $siteUrl)

Function Site-WakeUp {
    param (
        $TestUrl = $siteUrl 
    )
    Write-Output "INFO: Warm up starting"

    $MaxAttempts = 20

    If (![string]::IsNullOrWhiteSpace($TestUrl)) {
        Write-Output "INFO: Making request to $TestUrl"
        Try {
            $stopwatch = [Diagnostics.Stopwatch]::StartNew()
            # Allow redirections on the warm up
            $response = Invoke-WebRequest -UseBasicParsing $TestUrl -MaximumRedirection 10
            $stopwatch.Stop()
            $statusCode = [int]$response.StatusCode
            Write-Output "INFO: $statusCode Warmed Up Site $TestUrl in $($stopwatch.ElapsedMilliseconds)s ms"
        } catch {
           ($_.Exception).Message
        }
       
         For ($i = 1; $i -le $MaxAttempts; $i++) {
            try {
                Write-Output "INFO: Checking Site attempt: $i"
                $stopwatch = [Diagnostics.Stopwatch]::StartNew()
                # Don't allow redirections on the check
                $response = Invoke-WebRequest -UseBasicParsing $TestUrl -MaximumRedirection 1
                $statusCode = [int]$response.StatusCode
                
                Write-Output "INFO: $statusCode Second request took $($stopwatch.Elapsed.Seconds)s"
                
                If ($statusCode -ge 200 -And $statusCode -lt 400) {
                    $status = 'OK'
                    break;
                }
                
                Start-Sleep -s 2
            } catch {
                ($_.Exception).Message
            }
            Start-Sleep -s 2
        }

        If ($statusCode -ge 200 -And $statusCode -lt 400) {
            # Hooray, it worked
        } Else {
            $status = 'ERROR'
            throw "ERROR: Warm up failed for " + $TestUrl
        }
    } Else {
        Write-Output "WARNING:No TestUrl configured for this machine."
        $status = 'WARNING'
        exit 2
        
    }

    Write-Output "Done"
    return $status
}

#region CheckDeploySlot and create if not exist
Write-Host ("Get azure web app deployment slot.") 
$webAppSlot = Get-AzureRmWebAppSlot -ResourceGroupName $resourceGroup -Name $webAppName -Slot $slotName -ErrorAction SilentlyContinue
$webApp = Get-AzureRmWebApp -ResourceGroupName $resourceGroup -Name $webAppName -ErrorAction SilentlyContinue
if ($webApp) {
    write-host ("Web app exist.")
} else {
    throw "Web app does not exist. Please create and configure web app on portal.azure.com and restart deployment."
    exit 0
}
# slot creating
if ($webAppSlot) {
    Write-Host ("Deployment slot exist.")
}
else {
    Write-Host ("Slot does not exit, create new.")
    try{
    $webAppSlot = New-AzureRmWebAppSlot -ResourceGroupName $resourceGroup -Name $webAppName -Slot $slotName -ErrorAction Stop
        if ($webAppSlot) {
            Write-Host ("Slot has been created.")
        else {
                throw "Unable to create deplyoment slot."
        }
        }
    }    
    catch{
      write-host -NoNewline -ForegroundColor red "`nFailed during creating slot:" 
      write-host (" {0}" -f ($_.exception).Message )
      Write-host -ForegroundColor red  "Swap failed"
      exit
    }
}
#endregion CheckDeploySlot and create if not exist

#region SwapSlot
Write-Host ("Start swap procedure.")

if ($webAppSlot.State -eq 'Running') {
    $state = "Running"
} else {
    $start = $webAppSlot | Start-AzureRmWebAppSlot
    Write-host ("Slot is stopped. Start slot for deployment")
    $state = "Stopped"
}

Write-host ("`n{0}`nStart site warm up." -f ("="*100))

# warm-up site
Site-WakeUp -TestUrl $siteUrl -Verbose

Write-Output ("`n`n`nWarm up is done. `n{0}" -f ("="*100))
Write-Output ("Swap slot: source slot - $slotName => destination slot - Production")
Switch-AzureRmWebAppSlot -SourceSlotName $slotName -DestinationSlotName "Production" -ResourceGroupName $resourceGroup -Name $webAppName

switch ($state) {
    Stopped { 
        Write-Output ("Stop deployment slot (becasue it was stopped)")
        $stopSlot = $webAppSlot | Stop-AzureRmWebAppSlot
        }
    Default {
        Write-Output "Start deployment slot (becasue it was running)"
        $startSlot = $webAppSlot | Start-AzureRmWebAppSlot
    }
}
#endregion SwapSlot

Write-Host ("Script has been executed.")