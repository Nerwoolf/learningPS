<#
.SYNOPSIS
    Short description
.DESCRIPTION
    Long description
.EXAMPLE
    PS C:\> <example usage>
    Explanation of what the example does
#>
for ($I = 1; $I -le 100; $I++ )
{
    Write-Progress -Activity "Search in Progress" -Status "$I% Complete:" -PercentComplete $I
    Start-Sleep 1
}