# src/Private/PathUtilities/Get-NearestExistingParent.ps1

<#
.SYNOPSIS
    Finds the nearest existing parent directory.

.DESCRIPTION
    The Get-NearestExistingParent cmdlet walks up the path hierarchy until it finds a directory that exists.
    This is primarily used for generating headers when the requested path does not exist.
#>
function Get-NearestExistingParent {
    param([string]$Path)

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
