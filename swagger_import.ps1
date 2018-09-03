# var example
param (
    #  $ResourceGroup = "crgd2",
    #  $ApiMgmtName = "crgd2crgapi",
    #  $SwaggerUrl = "http://crgd2-businesscore.azurewebsites.net:80/swagger/docs/v1",
    #  $ApiSlotName = "Business Core Web API",
    #  $ApiDescr = "ColemanRG - $ApiSlotName",
    #  $ApiServiceUrl = "http://crgd2-businesscore.azurewebsites.net",
    #  $ApiPath = "core",
    #  $Product = "CRG Developers",
    #  $Policy = ''
)
begin { 
    # Octous  parameter set. In case of local tesing, use param block
    $ResourceGroup =  $SysAzureResourceGroupName 
    $ApiMgmtName =  $SysAzureAPImServiceName
    $SwaggerUrl =  "$SysSwaggerURL"
    $ApiSlotName = "$SysAzureAPImAPIName"
    $ApiDescr = "$SysAzureAPImAPIDescription"
    $ApiServiceUrl = "$SysAzureAPImAPIServiceUrl"
    $ApiPath = "$SysAzureAPImAPIPath"
    $Product = "$SysAzureAPImProduct"
    $Policy = '{0}' -f $SysAzureRmAPIMgmtPolicies

    function Test ($command, $text) {
        if (($command -ne $null) -or ($command -eq $True)) {
            return $True, (Write-Host -ForegroundColor "green" "+ Passed - $text"),$command
        } else {
            
            return $false, (Write-Host -ForegroundColor "red" "- Failed - The test ->$text-< is failed.`n $command"),$command
        }
    } 
    
    $defaultPolicy = '
        <policies>
            <inbound>
                <base />
                <cors>
                    <allowed-origins>
                        <origin>*</origin>
                        <!-- allow any -->
                    </allowed-origins>
                    <allowed-methods>
                        <!-- allow any -->
                        <method>*</method>
                    </allowed-methods>
                    <allowed-headers>
                        <!-- allow any -->
                        <header>*</header>
                    </allowed-headers>
                </cors>
            </inbound>
            <backend>
                <base />
            </backend>
            <outbound>
                <base />
            </outbound>
        </policies>
    '           
    if ($Policy.Length -eq 0) {
        $policy = $defaultPolicy
    } else {
        $policy = $Policy
    }
    $protocols = @("http","https")

    Write-Output ("INFO: Publish API for '{0}' to Azure API management:`n  - path={2}`n  - swagger url={3}`n  - product={4}`n  - api maangement={5},`n  - protocols={6}`n  - description={7}" -f $ApiSlotName, `
                                                                                                                                                        $ApiMgmtName, `
                                                                                                                                                        $ApiPath, `
                                                                                                                                                        $SwaggerUrl, `
                                                                                                                                                        $Product, `
                                                                                                                                                        $ApiMgmtName, `
                                                                                                                                                        ("{0},{1}" -f $protocols[0],$protocols[1]), `
                                                                                                                                                        $ApiDescr);
    Write-Output ("INFO: Once the backend API is imported into API Management, the  API Management API becomes a facade for the backend API.");


    # create security context
    $context = New-AzureRmApiManagementContext -ResourceGroupName $ResourceGroup `
                                               -ServiceName $ApiMgmtName;
    # get API
    $_sb_Api =  { Get-AzureRmApiManagementApi -Context $context | where {$_.Name -eq "$ApiSlotName"} -ErrorAction SilentlyContinue; };
    # product id 
    $product = Get-AzureRmApiManagementProduct -Context $context -Title ("{0}" -f $Product); 

     # api definition                  
          
    $api = Invoke-Command -ScriptBlock $_sb_Api;
    
    $_sb_Test = {
            # run simple  tests
            $test_apiNameIsMatch = Test -command ($api.Name -like $ApiSlotName) -text "Remote API name is match with user set";
            ###########################
            $test_apiExist = Test -command $api -text "API managment slot exist";
            ###########################
            $test_apiContainsOperation =  Test -command (Get-AzureRmApiManagementOperation -Context $context -ApiId $api.ApiId) -text "API contains operation";
            ###########################
            $test_apiProduct =  Test -command (Get-AzureRmApiManagementProduct -Context $context -ProductId $product.ProductId) -text "API product exist";
            ###########################
            $test_apiPathIsFreeCommand = Invoke-Command -ScriptBlock { if((Get-AzureRmApiManagementApi -Context $context | where {$_.Path -eq $ApiPath}).Name -eq $ApiSlotName) { return $true}else {$false,(Get-AzureRmApiManagementApi -Context $context | where {$_.Path -eq $ApiPath})}}
            $test_apiPathIsFree = Test -command $test_apiPathIsFreeCommand `
                                    -text "The provided API path can be used or belong to the current API"
            ##########################
            $test_200FromSite = Test -command (Invoke-WebRequest -Uri $SwaggerUrl).StatusCode -text "Status code from swagger is 200";
    }
    $ErrorActionPreference = "SilentlyContinue"  
    Write-Output ("`nINFO:Run tests.")
    Invoke-Command -ScriptBlock $_sb_Test
    $ErrorActionPreference = "Continue"  
   
}
process{
    # if api doesn't exist - create new, else - skip    
    try {
        if (!$api) {
            Write-Warning ("WARNING:The API Management API slot with name '{0}' doesn't exit.`nCreate new:" -f $ApiSlotName)
            Write-Output ("   - name={0}`n   - description={1}`n   - service url={2}`n   - path={3}`n   - protocols={4}`n   - product={5}" -f `
                                                                                                                                            $ApiSlotName, `
                                                                                                                                            $ApiDescr, `
                                                                                                                                            $ApiServiceUrl, `
                                                                                                                                            $ApiPath, `
                                                                                                                                            ("{0},{1}" -f $protocols[0],$protocols[1]), `
                                                                                                                                            $product.Title)
            New-AzureRmApiManagementApi -Context $context `
                                        -Name $ApiSlotName `
                                        -Description $ApiDescr `
                                        -ServiceUrl $ApiServiceUrl `
                                        -Path $ApiPath `
                                        -Protocols $protocols `
                                        -ProductIds $product.ProductId;
                                        
            # get api definition
            $api = Invoke-Command -ScriptBlock $_sb_Api         
            Write-Output ("INFO: The API Management API slot has been created:`n" -f ($api | Format-List -Property 'ApiId','Name','Description','ServiceUrl','Protocols','Path','Id'))
        }
    } catch{
        Write-Error ("ERROR: Failed to create Api Management API slot.")
        exit 1 
    }
    
    
    # import swagger specification to api management
    Write-Output ("`nINFO:Import swagger specification.")
    $import = $api | Import-AzureRmApiManagementApi -Context $context `
                                                    -ApiId $api.ApiId `
                                                    -SpecificationFormat "Swagger" `
                                                    -SpecificationUrl $SwaggerUrl;

    # set api management protocols 
    Write-Output ("`nINFO: Set API protocols.")
    $api |  Set-AzureRmApiManagementApi -Context $context `
                                        -Path $api.Path `
                                        -Protocols $protocols;
    
    # set api management product
    Write-Output ("`nINFO: Add API to product.")
    $api | Add-AzureRmApiManagementApiToProduct -Context $context -ProductId $product.ProductId
    Write-Output ("`nINFO: Set API CORS policy.")
    $api | Set-AzureRmApiManagementPolicy -Context $context `
                                          -Policy $policy `
                                          -ApiId $api.ApiId
}
end {
    Write-Output ("`nINFO: Run tests.")
    Invoke-Command -ScriptBlock $_sb_Test
    Write-Output ("`nScript execution has been Completed!")
}