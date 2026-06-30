# src/Private/Filtering/ConvertTo-TreeFilterPattern.ps1

<#
.SYNOPSIS
    Normalizes a glob pattern into a filter object.

.DESCRIPTION
    ConvertTo-TreeFilterPattern takes a raw string pattern and determines if it is a 
    name-only pattern or a path-rooted pattern. It normalizes path separators and 
    detects if the pattern is restricted to directories (indicated by a trailing slash).
#>
function ConvertTo-TreeFilterPattern {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Pattern,

        [string]$RootPath
    )

    if (-not $PSBoundParameters.ContainsKey('Debug') -and $PSCmdlet)
    {
        $DebugPreference = $PSCmdlet.GetVariableValue('DebugPreference')
    }
    if (-not $PSBoundParameters.ContainsKey('Verbose') -and $PSCmdlet)
    {
        $VerbosePreference = $PSCmdlet.GetVariableValue('VerbosePreference')
    }
    
    $directoryOnly = $Pattern.EndsWith([System.IO.Path]::DirectorySeparatorChar) -or $Pattern.EndsWith('/')

    # Normalize separators to the platform default
    $normalizedPattern = ($Pattern -replace '[\\/]', [System.IO.Path]::DirectorySeparatorChar).TrimEnd([System.IO.Path]::DirectorySeparatorChar)

    [PSCustomObject]@{
        Raw           = $Pattern
        Pattern       = $normalizedPattern
        DirectoryOnly = $directoryOnly
    }
}
