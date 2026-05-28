# src/Private/PathUtilities/Get-NearestExistingParent.ps1

<#
.SYNOPSIS
    Finds the nearest existing parent directory.

.DESCRIPTION
    Used for Tree.com header generation when the target path
    does not fully exist.
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
