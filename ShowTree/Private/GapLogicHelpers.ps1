# ShowTree\Private\GapLogicHelpers.ps1

# Gap Logic Helpers
<#
.SYNOPSIS
    Determines whether a directory has visible children.

.DESCRIPTION
    Used to decide whether to print a sibling/cousin gap.
    Respects MaxDepth and treats reparse points as leaf nodes.
#>
function Test-HasChildrenForGap {
    param(
        $Dir,
        [int]$CurrentDepth,
        [int]$MaxDepth
    )

    if (Test-IsReparsePoint $Dir) {
        return $false
    }

    # Depth cap: treat as empty if recursion would stop here
    if ($MaxDepth -ne -1 -and $CurrentDepth + 1 -ge $MaxDepth) {
        return $false
    }

    $children = Get-ChildItem -LiteralPath $Dir.FullName -Force -ErrorAction SilentlyContinue
    return $children.Count -gt 0
}

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
