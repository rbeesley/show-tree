# src\Private\Get-FilteredTreeItems.ps1

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

    The function accepts tree items either through -Items or from the pipeline.

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
    The collection of tree item objects to filter. The function preserves the
    original ordering of this list.

.INPUTS
    ShowTree.TreeItem

.OUTPUTS
    ShowTree.TreeItem
#>
function Get-FilteredTreeItems {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline)]
        [object[]]$Items,

        [string[]]$Include,
        [string[]]$Exclude,

        [switch]$HideHidden,
        [switch]$HideSystem,
        [switch]$DirectoryOnly
    )

    begin {
        $pipelineItems = [System.Collections.Generic.List[object]]::new()
    }

    process {
        foreach ($item in $Items) {
            if ($null -ne $item) {
                $pipelineItems.Add($item)
            }
        }
    }

    end {
        if ($pipelineItems.Count -eq 0) {
            return @()
        }

        #
        # Capture original order
        #
        $orig = @($pipelineItems)

        #
        # Hidden/System sets
        #
        $hidden = [System.Collections.Generic.List[object]]::new()
        if ($HideHidden) {
            foreach ($item in $orig) {
                if ($item.IsHidden -eq $true -or ($item.Native.FileAttributes -ne $null -and ($item.Native.FileAttributes -band [IO.FileAttributes]::Hidden) -ne 0)) {
                    $hidden.Add($item)
                }
            }
        }

        $system = [System.Collections.Generic.List[object]]::new()
        if ($HideSystem) {
            foreach ($item in $orig) {
                if ($item.Native.FileAttributes -ne $null -and ($item.Native.FileAttributes -band [IO.FileAttributes]::System) -ne 0) {
                    $system.Add($item)
                }
            }
        }

        #
        # Exclude sets (exact + glob)
        #
        $excludedExact = @()
        $excludedGlob  = @()

        if ($Exclude) {
            foreach ($item in $orig) {
                $name = $item.Name
                if ($Exclude -contains $name) { $excludedExact += $item; continue }
                if ($Exclude) {
                    foreach ($pattern in $Exclude) {
                        if ($name -like $pattern) { $excludedGlob += $item; break }
                    }
                }
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
                if ($Include) {
                    foreach ($pattern in $Include) {
                        if ($name -like $pattern) { $includedGlob += $item; break }
                    }
                }
            }
        }

        #
        # Final filtering (stable order)
        #
        [object[]]$final = foreach ($item in $orig) {
            $isHidden        = $HideHidden ? ($hidden -contains $item) : $false
            $isSystem        = $HideSystem ? ($system -contains $item) : $false
            $isExcludedExact = $excludedExact -contains $item
            $isExcludedGlob  = $excludedGlob  -contains $item
            $isIncludedExact = $includedExact -contains $item
            $isIncludedGlob  = $includedGlob  -contains $item
            $isFileToRemove  = $DirectoryOnly -and -not $item.IsContainer

            #
            # Decision logic
            #
            if ($isIncludedExact) { $item; continue }   # exact include wins
            if ($isFileToRemove)  { continue }          # directory only removes files
            if ($isExcludedExact) { continue }          # exact exclude wins
            if ($isIncludedGlob)  { $item; continue }   # glob include resurrects
            if ($isHidden)        { continue }          # hidden removes unless included
            if ($isSystem)        { continue }          # system removes unless included
            if ($isExcludedGlob)  { continue }          # glob exclude removes unless included

            $item
        }

        return $final
    }
}