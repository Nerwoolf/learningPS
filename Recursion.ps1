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
<#function Get-AllRabbits([int]$month) {
if ($month -lt 0) {
[int]$month = 0
}
if ($month -eq 0 -or $month -eq 1) {
Write-Output 1
} else {
[int]$prev = Get-AllRabbits([int]$month - 1)
[int]$prevprev = Get-AllRabbits([int]$month - 2)
Write-Output ($prev + $prevprev)
}
} 

#>