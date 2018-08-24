# Get first 36 computers in AD
$computers = (Get-ADComputer -Filter * | Select-Object -First 36).name
# 
Get-CimInstance -ClassName CIM_Service -ComputerName $computers `
| Where-Object {$_.Name} | Sort-Object StartMode, Started `
| Format-Table  name, status, startmode, started 
    