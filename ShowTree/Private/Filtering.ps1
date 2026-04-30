# ShowTree\Private\Filtering.ps1

# Filtering
<#
.SYNOPSIS
    Returns a filtered subset of tree items using Hidden/System attributes and
    PowerShell-style Include/Exclude glob patterns while preserving original order.

.DESCRIPTION
    Get-FilteredTreeItems applies all Show-Tree filtering rules to a collection of
    filesystem items and returns the resulting subset in stable, original order.

    Filtering supports:
    • Hidden and System attribute removal (-HideHidden, -HideSystem)
    • PowerShell-style glob patterns for -Include and -Exclude
    • Exact-match and glob-match precedence rules
    • Include selectively overriding Exclude, Hidden, and System
    • Exclude exact-match patterns taking precedence over globbed Include patterns

    The function evaluates each item against four independent removal sets:
    Hidden, System, ExcludedExact, and ExcludedGlob. It also computes two inclusion
    sets: IncludedExact and IncludedGlob.

    Final item selection follows these rules:

    1. Exact Include always wins.
    2. Exact Exclude always wins, even if the item matches a broader Include glob.
    3. Glob Include resurrects items removed by Hidden, System, or glob Exclude.
    4. Hidden and System remove items unless resurrected by Include.
    5. Glob Exclude removes items unless resurrected by Include.
    6. Items not affected by any rule are kept.

    This produces intuitive, PowerShell-like filtering behavior while maintaining
    the original enumeration order required for correct tree rendering.

.PARAMETER Items
    The collection of file or directory objects to filter. The function preserves
    the original ordering of this list.
#>
function Get-FilteredTreeItems {
    param(
        [array]$Items,

        [string[]]$Include,
        [string[]]$Exclude,

        [switch]$HideHidden,
        [switch]$HideSystem
    )

    if (-not $Items) {
        return @()
    }

    #
    # Capture original order
    #
    $orig = $Items

    #
    # Hidden/System sets
    #
    $hidden = $HideHidden ? ($orig | Where-Object { $_.Attributes -band [IO.FileAttributes]::Hidden }) : @()
    $system = $HideSystem ? ($orig | Where-Object { $_.Attributes -band [IO.FileAttributes]::System }) : @()

    #
    # Exclude sets (exact + glob)
    #
    $excludedExact = @()
    $excludedGlob  = @()

    if ($Exclude) {
        foreach ($item in $orig) {
            $name = $item.Name
            if ($Exclude -contains $name) { $excludedExact += $item; continue }
            if ($Exclude | Where-Object { $name -like $_ }) { $excludedGlob += $item }
        }
    }

    #
    # Include sets (exact + glob)
    #
    $includedExact = @()
    $includedGlob  = @()

    if ($Include) {
        foreach ($item in $orig) {
            $name = $item.Name
            if ($Include -contains $name) { $includedExact += $item; continue }
            if ($Include | Where-Object { $name -like $_ }) { $includedGlob += $item }
        }
    }

    #
    # Final filtering (stable order)
    #
    $final = foreach ($item in $orig) {
        $name = $item.Name

        $isHidden        = $hidden        -contains $item
        $isSystem        = $system        -contains $item
        $isExcludedExact = $excludedExact -contains $item
        $isExcludedGlob  = $excludedGlob  -contains $item
        $isIncludedExact = $includedExact -contains $item
        $isIncludedGlob  = $includedGlob  -contains $item

        #
        # Decision logic
        #
        if ($isIncludedExact) { $item; continue }   # exact include wins
        if ($isExcludedExact) { continue }          # exact exclude wins
        if ($isIncludedGlob)  { $item; continue }   # glob include resurrects
        if ($isHidden)        { continue }          # hidden removes unless included
        if ($isSystem)        { continue }          # system removes unless included
        if ($isExcludedGlob)  { continue }          # glob exclude removes unless included

        $item
    }

    return $final
}
