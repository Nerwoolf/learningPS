# Get first 36 computers in AD
$computers = (Get-ADComputer -Filter * | Select-Object -First 36).name
# We have no access to computers in network, so we don't use $computers 
Get-CimInstance -ClassName CIM_Service -ComputerName localhost `
| Where-Object {$_.Name} | Sort-Object StartMode, Started `
| Format-Table  name, status, startmode, started 
    