# src/Private/Traversal/New-TreeRecord.ps1

<#
.SYNOPSIS
    Creates a streamed tree traversal record.

.DESCRIPTION
    The New-TreeRecord cmdlet creates a ShowTree.TreeRecord object, which is the primary unit of data
    piped from traversal to formatting. It contains an item or a formatting gap, along with its layout metadata.
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

    if ($RecordType -eq 'Item' -and $null -eq $TreeItem) {
        throw "Tree record type 'Item' requires a TreeItem."
    }

    if ($null -eq $TreeLayout.PSTypeNames -or $TreeLayout.PSTypeNames -notcontains 'ShowTree.TreeLayout') {
        throw "Tree record requires a ShowTree.TreeLayout layout object."
    }

    [PSCustomObject]@{
        PSTypeName = 'ShowTree.TreeRecord'
        RecordType = $RecordType
        TreeItem   = $TreeItem
        TreeLayout = $TreeLayout
    }
}