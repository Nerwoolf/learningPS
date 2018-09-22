function Get-IniContent  {
    Param (
        [String]$Filepath
    )
    $IniContent = @{}
    switch -Regex -File $Filepath {
        '^\[(.+)\]' {
            $Section = $matches[1]
            $IniContent[$Section] = @{}
            $CommentCount = 0
        }
        "^(;.*)$"  {
            $Value = $matches[1]
            $CommentCount = $CommentCount + 1
            $Name = 'Comment' + $CommentCount
            $IniContent[$Section][$Name] = $Value
        }
        '(.+?)\s*=(.*)' {
            $Name, $Value = $matches[1..2]
            $IniContent[$Section][$Name] = $Value
        }
    }
    Write-Output $IniContent
}