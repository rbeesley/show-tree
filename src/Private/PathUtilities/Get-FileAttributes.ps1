# src/Private/PathUtilities/Get-FileAttributes.ps1

<#
.SYNOPSIS
    Enumerates all set file attributes on an item.

.DESCRIPTION
    Used by Get-ItemStyle to apply attribute overlays.
#>
function Get-FileAttributes {
    param([IO.FileAttributes]$Attributes)

    foreach ($flag in [System.Enum]::GetValues([IO.FileAttributes])) {
        if ($Attributes -band $flag) {
            $flag
        }
    }
}