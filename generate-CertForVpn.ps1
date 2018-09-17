<#
.SYNOPSIS
    generate-CertForVpn.ps1
.DESCRIPTION
    Long description
.EXAMPLE
    PS C:\> <example usage>
    Explanation of what the example does
.INPUTS
    Inputs (if any)
.OUTPUTS
    Output (if any)
.NOTES
    General notes
#>
function generate-CertForVpn{
param(
    [Parameter(Mandatory=$true)]
    [String]$RootCertName,

    [Parameter(Mandatory=$true)]
    [String]$ChildCertName,

    [Parameter(Mandatory=$true)]
    [string]$Password
)
begin{
    $pathToExport = (Get-ChildItem Env:\USERPROFILE).value
    $PasswordSec = ConvertTo-SecureString -String $Password -AsPlainText -Force
}
process{
    if((Get-ChildItem Cert:\CurrentUser\My | Where-Object -Property Subject -Match "$RootCertName") -ne $null){
        Write-host ("Certificate $RootCertName already exist")
        exit 1
    }
    else {
        
    # Creating root certificateSS
    $rootCert = New-SelfSignedCertificate -Type Custom `
                                      -KeySpec Signature `
                                      -Subject ("CN={0}" -f $RootCertName) `
                                      -KeyExportPolicy Exportable `
                                      -HashAlgorithm sha256 `
                                      -KeyLength 2048 `
                                      -CertStoreLocation "Cert:\CurrentUser\My" `
                                      -KeyUsageProperty Sign `
                                      -KeyUsage CertSign
    
    # Creating client certificate
    $clientCert = New-SelfSignedCertificate -Type Custom `
                              -DnsName P2SChildCert `
                              -KeySpec Signature `
                              -Subject ("CN={0}" -f $ChildCertName) `
                              -KeyExportPolicy Exportable `
                              -HashAlgorithm sha256 `
                              -KeyLength 2048 `
                              -CertStoreLocation "Cert:\CurrentUser\My" `
                              -Signer $rootCert `
                              -TextExtension @("2.5.29.37={text}1.3.6.1.5.5.7.3.2")
    
    # Export Root certificate value for azure portal
    $rootCertValue = [convert]::tobase64string($rootCert.RawData)
    
    # Export Client certificate privat key
    Export-PfxCertificate -FilePath ("{0}\Desktop\{1}.pfx" -f $pathToExport, $ChildCertName) -Cert $clientCert -ChainOption BuildChain -Password $PasswordSec
    $clientCertCheck = Get-ChildItem -Path ("{0}\Desktop\{1}.pfx" -f $pathToExport, $ChildCertName) -ErrorAction SilentlyContinue
    }
}
end{

    Write-Host ("`n`nCopy this text to azure portal for point to site VPN :`n{0}`n`n" -f $rootCertValue)
    if($clientCertCheck -ne $null){
        Write-host ("`n`n`nAt your desktop you will find client certificate for VPN setting up. Certificate name: {0}" -f $ChildCertName)
    }
    else{
        Write-Host "Something going wrong and certificate was not created"
    }
}
}
generate-CertForVpn -RootCertName "Azure-VPN" -ChildCertName "Client"  -Password "123qweasd"