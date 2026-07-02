# src/Private/Traversal/New-TreeLayout.ps1

<#
.SYNOPSIS
    Creates a TreeLayout object for a record.

.DESCRIPTION
    New-TreeLayout calculates the indentation and connector state for a tree item. 
    It tracks whether an item is the last sibling and carries forward the "last sibling" 
    status of ancestors to correctly draw vertical span lines.
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

    if (-not $PSBoundParameters.ContainsKey('Debug') -and $PSCmdlet)
    {
        $DebugPreference = $PSCmdlet.GetVariableValue('DebugPreference')
    }
    if (-not $PSBoundParameters.ContainsKey('Verbose') -and $PSCmdlet)
    {
        $VerbosePreference = $PSCmdlet.GetVariableValue('VerbosePreference')
    }

    [PSCustomObject]@{
        PSTypeName                = 'ShowTree.TreeLayout'
        Depth                     = $Depth
        RelativeDepth             = $RelativeDepth
        IsLastSibling             = [bool] $IsLastSibling
        AncestorIsLastSibling     = @($AncestorIsLastSibling)
        HasLaterSiblingDirectory  = [bool] $HasLaterSiblingDirectory
    }
}
