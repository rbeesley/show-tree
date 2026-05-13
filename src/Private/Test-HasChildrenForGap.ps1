# src\Private\Test-HasChildrenForGap.ps1

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
