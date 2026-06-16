# src/Private/Traversal/Invoke-TreeTraversal.ps1

<#
.SYNOPSIS
    Streams tree traversal records for a path.

.DESCRIPTION
    The Invoke-TreeTraversal cmdlet performs a depth-first traversal of a directory structure.
    It emits ShowTree.TreeRecord objects for each item and for "gaps" (formatting markers).
    It manages the traversal depth and applies filtering and visibility rules.
#>
function Invoke-TreeTraversal {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $Path,

        [string] $RootPath,

        [int] $MaxDepth = -1,

        [int] $CurrentDepth = 0,

        [Parameter(Mandatory)]
        [object] $Provider,

        [bool[]] $AncestorIsLastSibling = @(),

        [bool] $HasNextSiblingAfterThisDirectory = $false,

        [string[]] $Include,
        [string[]] $Exclude,

        [switch] $HideHidden,
        [switch] $HideSystem,
        [switch] $DirectoryOnly,
        [switch] $FollowLinks
    )

    if ([string]::IsNullOrWhiteSpace($RootPath)) {
        $RootPath = $Path
    }

    $children = @(
        Get-ImmediateTreeChild `
            -Path $Path `
            -RootPath $RootPath `
            -Depth $CurrentDepth `
            -Provider $Provider `
            -Include $Include `
            -Exclude $Exclude `
            -HideHidden:$HideHidden `
            -HideSystem:$HideSystem `
            -DirectoryOnly:$DirectoryOnly
    )

    $emittedVisibleChild = $false

    if ($children.Count -eq 0) {
        return
    }

    for ($i = 0; $i -lt $children.Count; $i++) {
        $child = $children[$i]
        $emittedVisibleChild = $true

        $isLastSibling = $i -eq ($children.Count - 1)
        $hasNextSibling = -not $isLastSibling

        $hasLaterSiblingDirectory = $false
        for ($j = $i + 1; $j -lt $children.Count; $j++) {
            if ($children[$j].IsContainer) {
                $hasLaterSiblingDirectory = $true
                break
            }
        }

        $layout = New-TreeLayout `
            -Depth $child.Depth `
            -RelativeDepth $child.Depth `
            -IsLastSibling:$isLastSibling `
            -AncestorIsLastSibling $AncestorIsLastSibling `
            -HasLaterSiblingDirectory:$hasLaterSiblingDirectory

        New-TreeRecord `
            -RecordType Item `
            -TreeItem $child `
            -TreeLayout $layout

        if (-not $child.IsContainer -and $hasNextSibling -and $children[$i + 1].IsContainer) {
            $fileToDirectoryGapLayout = New-TreeLayout `
                -Depth $CurrentDepth `
                -RelativeDepth $CurrentDepth `
                -AncestorIsLastSibling $AncestorIsLastSibling

            New-TreeRecord `
                -RecordType Gap `
                -TreeLayout $fileToDirectoryGapLayout
        }

        $shouldRecurse =
            $child.IsContainer -and
            ($MaxDepth -eq -1 -or $CurrentDepth -lt $MaxDepth) -and
            (Test-TreeItemRecurse `
                -Item $child `
                -Include $Include `
                -Exclude $Exclude `
                -RootPath $RootPath `
                -HideHidden:$HideHidden `
                -HideSystem:$HideSystem `
                -FollowLinks:$FollowLinks)

        if ($shouldRecurse) {
            $nextAncestorIsLastSibling = [System.Collections.Generic.List[bool]]::new()

            foreach ($ancestorIsLast in $AncestorIsLastSibling) {
                [void] $nextAncestorIsLastSibling.Add([bool] $ancestorIsLast)
            }

            [void] $nextAncestorIsLastSibling.Add([bool] $isLastSibling)

            $recurseParams = @{
                Path                             = $child.FullPath
                RootPath                         = $RootPath
                MaxDepth                         = $MaxDepth
                CurrentDepth                     = $CurrentDepth + 1
                Provider                         = $Provider
                HasNextSiblingAfterThisDirectory = $hasNextSibling
                Include                          = $Include
                Exclude                          = $Exclude
                HideHidden                       = $HideHidden
                HideSystem                       = $HideSystem
                DirectoryOnly                    = $DirectoryOnly
                FollowLinks                      = $FollowLinks
            }

            $nextAncestorArray = $nextAncestorIsLastSibling.ToArray()
            if ($nextAncestorArray.Count -gt 0) {
                $recurseParams.AncestorIsLastSibling = $nextAncestorArray
            }

            Invoke-TreeTraversal @recurseParams
        }
    }

    if ($emittedVisibleChild -and $HasNextSiblingAfterThisDirectory) {
        $gapAncestorIsLastSibling = [System.Collections.Generic.List[bool]]::new()

        if ($AncestorIsLastSibling.Count -gt 1) {
            for ($i = 0; $i -lt ($AncestorIsLastSibling.Count - 1); $i++) {
                [void] $gapAncestorIsLastSibling.Add([bool] $AncestorIsLastSibling[$i])
            }
        }

        $gapDepth = if ($CurrentDepth -gt 0) {
            $CurrentDepth - 1
        }
        else {
            0
        }

        $gapLayoutParams = @{
            Depth          = $gapDepth
            RelativeDepth  = $gapDepth
        }

        $gapAncestorArray = $gapAncestorIsLastSibling.ToArray()
        if ($gapAncestorArray.Count -gt 0) {
            $gapLayoutParams.AncestorIsLastSibling = $gapAncestorArray
        }

        $gapLayout = New-TreeLayout @gapLayoutParams

        New-TreeRecord `
            -RecordType Gap `
            -TreeLayout $gapLayout
    }
}
