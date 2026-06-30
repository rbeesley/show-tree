# src/Private/PathUtilities/Get-NearestExistingParent.ps1

<#
.SYNOPSIS
    Finds the nearest existing parent directory.

.DESCRIPTION
    The Get-NearestExistingParent cmdlet walks up the path hierarchy until it finds a 
    directory that exists on disk. This is used to resolve volume information even 
    when the requested sub-path does not exist.
#>
function Get-NearestExistingParent {
    param([string]$Path)

    if (-not $PSBoundParameters.ContainsKey('Debug') -and $PSCmdlet)
    {
        $DebugPreference = $PSCmdlet.GetVariableValue('DebugPreference')
    }
    if (-not $PSBoundParameters.ContainsKey('Verbose') -and $PSCmdlet)
    {
        $VerbosePreference = $PSCmdlet.GetVariableValue('VerbosePreference')
    }

    $current = [System.IO.Path]::GetFullPath($Path)

    while (-not (Test-Path $current)) {
        $parent = [System.IO.Directory]::GetParent($current)
        if ($null -eq $parent) {
            return $null
        }
        $current = $parent.FullName
    }

    $current
}
