# src/Private/Traversal/New-TreeLayout.ps1

<#
.SYNOPSIS
    Creates layout metadata for a streamed tree record.

.DESCRIPTION
    The New-TreeLayout cmdlet creates a ShowTree.TreeLayout object that describes the positional state
    of an item in the tree (depth, whether it's the last sibling, etc.), which is used by Format-Tree for rendering.
#>
function New-TreeLayout {
    [CmdletBinding()]
    param(
        [int] $Depth = 0,

        [int] $RelativeDepth = $Depth,

        [bool] $IsLastSibling = $false,

        [bool[]] $AncestorIsLastSibling = @(),

        [bool] $HasLaterSiblingDirectory = $false
    )

    [PSCustomObject]@{
        PSTypeName                = 'ShowTree.TreeLayout'
        Depth                     = $Depth
        RelativeDepth             = $RelativeDepth
        IsLastSibling             = [bool] $IsLastSibling
        AncestorIsLastSibling     = @($AncestorIsLastSibling)
        HasLaterSiblingDirectory  = [bool] $HasLaterSiblingDirectory
    }
}
