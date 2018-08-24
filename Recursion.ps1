<#
.Synopsis
   Recursion.ps1
.DESCRIPTION
   This function show a simple example of how recursion work. Countdown
.EXAMPLE
   countdown(10)
#>
function countdown([int]$b) {
    if ($b -eq 0){
        
        
        Write-Host 'finish'
        exit
    }
        
        Write-Host $b
        Start-Sleep 1
        countdown(--$b)
        
        
    

    
}
$input = Read-Host 'Input Number'
countdown($input)