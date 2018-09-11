<#
.SYNOPSIS
    url_git_valid.ps1
.DESCRIPTION
    Validate git path
.EXAMPLE
    PS C:\> url_git_valid.ps1 -branchname refs/heads/FB/11.1/DBAUtil_Changes
#>

function Check-Branchname() {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [String]$path
    )
    
    begin {

        $resultMessageValid = "Path is correct"
        $resultMessageFail = "Path is not correct"
        # Regex pattern for path validating
        $pathValidateRegex = "^([\/]?\w*[\/\.\-\_]{0,1}\w*[\/]?)+$"
    }
    
    process {

        if($path -eq $pathValidateRegex){
            Write-Output $resultMessageValid
            $result = $true
        }
        else {
            Write-Output $resultMessageFail
            $result = $false
        }
    }
    
    end {
        return $result
    }
}

Check-Branchname