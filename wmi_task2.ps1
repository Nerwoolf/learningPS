# Get first 10 computers in AD
$computers = (Get-ADComputer -Filter * | Select-Object -First 10).name
# Ping each PC
foreach ($computer in $computers) {
    $ping = get-wmiobject -Query "select * from win32_pingstatus where Address='$computer'"

    # Display Results 
    if ($ping.statuscode -eq 0) {
        "Computer {1} responded in: {0} ms" -f $ping.responsetime, $computer
    }
    else {

        "Computer $computer did not respond"

    }
}
