function Get-AllRabbits($month) {
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
Get-AllRabbits(1100)