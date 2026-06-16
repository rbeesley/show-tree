# src/Private/TestItemPredicates.ps1

<#
.SYNOPSIS
    Internal predicate functions for filtering and testing tree items.

.DESCRIPTION
    This file contains several internal functions used to determine the visibility and 
    recursion behavior of items during a tree traversal:
    - ConvertTo-TreeFilterPattern: Normalizes glob patterns.
    - Get-TreeItemRelativePath: Computes the path of an item relative to the traversal root.
    - Test-TreeItemFilterMatch: Tests if an item matches an include/exclude pattern.
    - Test-TreeItemVisible: Determines if an item should be displayed.
    - Test-TreeItemRecurse: Determines if a directory should be traversed.
#>
function ConvertTo-TreeFilterPattern {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Pattern
    )

    $directoryOnly = $Pattern.EndsWith('\') -or $Pattern.EndsWith('/')

    $normalized = $Pattern -replace '/', '\'
    $normalized = $normalized.TrimEnd('\')

    $isExplicitRelativePath = $normalized.StartsWith('.\')

    if ($isExplicitRelativePath) {
        $normalized = $normalized.Substring(2)
    }

    $isPathPattern = $isExplicitRelativePath -or $normalized.Contains('\')

    [PSCustomObject]@{
        Raw           = $Pattern
        Pattern       = $normalized
        DirectoryOnly = $directoryOnly
        IsPathPattern = $isPathPattern
    }
}

function Get-TreeItemRelativePath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Item,

        [string]$RootPath
    )

    if ([string]::IsNullOrWhiteSpace($RootPath)) {
        return $null
    }

    $root = [System.IO.Path]::GetFullPath($RootPath).TrimEnd('\', '/')
    $full = [System.IO.Path]::GetFullPath($Item.FullPath).TrimEnd('\', '/')

    if (-not $full.StartsWith($root, [System.StringComparison]::OrdinalIgnoreCase)) {
        return $null
    }

    $relative = $full.Substring($root.Length).TrimStart('\', '/')
    $relative -replace '/', '\'
}

function Test-TreeItemFilterMatch {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Item,

        [Parameter(Mandatory)]
        [string]$Pattern,

        [string]$RootPath
    )

    $filter = ConvertTo-TreeFilterPattern -Pattern $Pattern

    if ($filter.DirectoryOnly -and -not $Item.IsContainer) {
        return $false
    }

    if ($filter.IsPathPattern) {
        $relativePath = Get-TreeItemRelativePath -Item $Item -RootPath $RootPath
        if ([string]::IsNullOrWhiteSpace($relativePath)) {
            return $false
        }

        return $relativePath -like $filter.Pattern
    }

    return $Item.Name -like $filter.Pattern
}

function Test-TreeItemVisible {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Item,

        [string[]]$Include,
        [string[]]$Exclude,

        [string]$RootPath,

        [switch]$HideHidden,
        [switch]$HideSystem,
        [switch]$DirectoryOnly
    )

    $name = $Item.Name

    $isIncludedExact = $Include -contains $name
    $isExcludedExact = $Exclude -contains $name

    $isIncludedGlob = $false
    if (-not $isIncludedExact -and $Include) {
        foreach ($pattern in $Include) {
            if (Test-TreeItemFilterMatch -Item $Item -Pattern $pattern -RootPath $RootPath) {
                $isIncludedGlob = $true
                break
            }
        }
    }

    $isExcludedGlob = $false
    if (-not $isExcludedExact -and $Exclude) {
        foreach ($pattern in $Exclude) {
            if (Test-TreeItemFilterMatch -Item $Item -Pattern $pattern -RootPath $RootPath) {
                $isExcludedGlob = $true
                break
            }
        }
    }

    $isHidden = $false
    if ($HideHidden) {
        $isHidden = $Item.IsHidden -eq $true -or
                ($null -ne $Item.Native.FileAttributes -and
                ($Item.Native.FileAttributes -band [IO.FileAttributes]::Hidden) -ne 0
        )
    }

    $isSystem = $false
    if ($HideSystem) {
        $isSystem = $null -ne $Item.Native.FileAttributes -and
                ($Item.Native.FileAttributes -band [IO.FileAttributes]::System) -ne 0
    }

    $isFileToRemove = $DirectoryOnly -and -not $Item.IsContainer

    if ($isIncludedExact) { return $true }
    if ($isFileToRemove)  { return $false }
    if ($isExcludedExact) { return $false }
    if ($isIncludedGlob)  { return $true }
    if ($isHidden)        { return $false }
    if ($isSystem)        { return $false }
    if ($isExcludedGlob)  { return $false }

    return $true
}

function Test-TreeItemRecurse {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Item,

        [string[]]$Include,
        [string[]]$Exclude,

        [string]$RootPath,

        [switch]$HideHidden,
        [switch]$HideSystem,

        [switch]$FollowLinks
    )

    # Only directories can be recursed into
    if (-not $Item.IsContainer) {
        return $false
    }

    # If it's a link and we don't follow links, don't recurse
    if ($Item.IsLink -and -not $FollowLinks) {
        return $false
    }

    $name = $Item.Name

    # Exclude/hide/system can prune traversal unless Include explicitly rescues the item.

    $isIncludedExact = $Include -contains $name
    $isExcludedExact = $Exclude -contains $name

    # If it's explicitly included, we should definitely recurse (if it's a directory)
    if ($isIncludedExact) {
        return $true
    }

    # If it's explicitly excluded, we should definitely NOT recurse
    if ($isExcludedExact) {
        return $false
    }

    # If it matches an exclude glob, don't recurse
    $isRescued = $false
    if ($Exclude) {
        foreach ($pattern in $Exclude) {
            if (Test-TreeItemFilterMatch -Item $Item -Pattern $pattern -RootPath $RootPath) {
                # Check if it's rescued by a glob include
                $isRescued = $false
                if ($Include) {
                    foreach ($incPattern in $Include) {
                        if (Test-TreeItemFilterMatch -Item $Item -Pattern $incPattern -RootPath $RootPath) {
                            $isRescued = $true
                            break
                        }
                    }
                }
                if (-not $isRescued) {
                    return $false
                }
                # If rescued by glob include, we continue to check HideHidden/HideSystem
                break
            }
        }
    }

    # If hidden/system and hidden/system are to be hidden
    if ($HideHidden) {
        $isHidden = $Item.IsHidden -eq $true -or (
        $null -ne $Item.Native.FileAttributes -and
                ($Item.Native.FileAttributes -band [IO.FileAttributes]::Hidden) -ne 0
        )
        if ($isHidden -and -not $isRescued) {
            return $false
        }
    }

    if ($HideSystem) {
        $isSystem = $null -ne $Item.Native.FileAttributes -and
                ($Item.Native.FileAttributes -band [IO.FileAttributes]::System) -ne 0
        if ($isSystem -and -not $isRescued) {
            return $false
        }
    }

    # SPECIAL CASE: If Include is specified, and this directory doesn't match it,
    # we STILL recurse because we might find matches deep inside.
    # This matches the "Visible? maybe no, Recurse? yes" logic in the issue description.

    # By default, recurse into directories
    return $true
}
