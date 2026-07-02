# src/Private/Traversal/New-TreeRecord.ps1

<#
.SYNOPSIS
    Creates a TreeRecord object.

.DESCRIPTION
    New-TreeRecord is a factory for ShowTree.TreeRecord objects. These objects 
    combine a TreeItem (the data) with a TreeLayout (the visual state) and are the 
    primary unit of communication between the traversal engine and the renderer.
#>
function New-TreeRecord {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Item', 'Gap')]
        [string] $RecordType,

        [object] $TreeItem,

        [Parameter(Mandatory)]
        [object] $TreeLayout
    )

    if (-not $PSBoundParameters.ContainsKey('Debug') -and $PSCmdlet)
    {
        $DebugPreference = $PSCmdlet.GetVariableValue('DebugPreference')
    }
    if (-not $PSBoundParameters.ContainsKey('Verbose') -and $PSCmdlet)
    {
        $VerbosePreference = $PSCmdlet.GetVariableValue('VerbosePreference')
    }

    $styleProfile = Get-ActiveShowTreeStyleProfile
    $uiErrors = $styleProfile.UIStrings.Errors

    if ($RecordType -eq 'Item' -and $null -eq $TreeItem) {
        throw $uiErrors.MissingTreeItem
    }

    if ($null -eq $TreeLayout.PSTypeNames -or $TreeLayout.PSTypeNames -notcontains 'ShowTree.TreeLayout') {
        throw $uiErrors.MissingTreeLayout
    }

    [PSCustomObject]@{
        PSTypeName = 'ShowTree.TreeRecord'
        RecordType = $RecordType
        TreeItem   = $TreeItem
        TreeLayout = $TreeLayout
    }
}