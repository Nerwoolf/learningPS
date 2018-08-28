param (
    $var1 = "123123",
    $var2 = "123123",
    $var3 = "123123"
)
begin{
    $uri = "https://www.papajohns.by/api/stock/codes"
    # some functions, varaibles
    #pre-configuration 
    function Write_codes () {
        param (
            $var1
        )
        write-host -BackgroundColor Red $var1
    }
}
process{
    $req = Invoke-WebRequest  -uri $uri
    $code_content = $req.Content | ConvertFrom-Json 
    $codes = $code_content.codes | Select-Object @{n="Code";e={$_.code}}
    Write-Output $codes 

}
end {
    
}



