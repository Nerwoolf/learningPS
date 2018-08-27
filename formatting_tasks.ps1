#  Display a table of processes that includes the process names and IDs. 
# Also include columns for virtual and physical memory usage, expressing those values in megabytes (MB)

get-process | Sort-Object -Property WorkingSet64, name -Descending `
| Format-Table -Property name, id, `
@{n="VM";e={[math]::round($_.virtualMemorySize64/1Mb)}},`
@{n="Physical memory";e={[math]::Round($_.WorkingSet64/1Mb)}} -AutoSize

# Display a list of services so that a separate table is displayed for services that 
# are started and services that are stopped. Services that are started should be displayed first.

Get-Service | Sort-Object Status -Descending | Format-Table -GroupBy status -AutoSize

 
 				





