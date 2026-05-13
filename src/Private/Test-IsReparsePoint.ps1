# src\Private\Test-IsReparsePoint.ps1

<#
.SYNOPSIS
    Checks whether an item is a reparse point.

.DESCRIPTION
    Reparse points (symlinks/junctions) are treated as leaf nodes
    for recursion and gap logic.
#>
function Test-IsReparsePoint {
    param($Item)
    [bool]($Item.Attributes -band [IO.FileAttributes]::ReparsePoint)
}
