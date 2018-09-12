begin{
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $uri = "https://www.papajohns.by/api/stock/codes"
}
process{
    $req = Invoke-WebRequest  -uri $uri
    $code_content = $req.Content | ConvertFrom-Json   
}
end {
    $code_content.codes | Select name, code | out-gridview -PassThru
}



