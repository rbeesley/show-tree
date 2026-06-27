# src/Private/TreeItemPredicates.ps1

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
        [string]$Pattern,

        [string]$RootPath
    )

    $directoryOnly = $Pattern.EndsWith('\') -or $Pattern.EndsWith('/')
    $isPathPattern = $Pattern.Contains('\') -or $Pattern.Contains('/')

    $normalized = $Pattern -replace '/', '\'
    $normalized = $normalized.TrimEnd('\')

    [PSCustomObject]@{
        Raw           = $Pattern
        Pattern       = $normalized
        DirectoryOnly = $directoryOnly
        IsPathPattern = $isPathPattern
    }
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

    $filter = ConvertTo-TreeFilterPattern -Pattern $Pattern -RootPath $RootPath

    if ($filter.DirectoryOnly -and -not $Item.IsContainer) {
        return $false
    }

    if ($filter.IsPathPattern) {
        $itemPath = [System.IO.Path]::GetFullPath($Item.FullPath).TrimEnd('\', '/')

        # Canonicalize the pattern path
        $patternPath = $filter.Pattern
        if (-not [System.IO.Path]::IsPathRooted($patternPath)) {
            $base = [string]::IsNullOrWhiteSpace($RootPath) ? $PWD.ProviderPath : $RootPath
            $patternPath = [System.IO.Path]::Combine($base, $patternPath)
        }
        $patternPath = [System.IO.Path]::GetFullPath($patternPath).TrimEnd('\', '/')

        $hasWildcard = $patternPath.Contains('*') -or $patternPath.Contains('?')
        if ($hasWildcard) {
            return $itemPath -like $patternPath -or $itemPath -like ($patternPath + '\*')
        }

        return $itemPath -eq $patternPath -or $itemPath.StartsWith($patternPath + '\', [System.StringComparison]::OrdinalIgnoreCase)
    }

    return $Item.Name -like $filter.Pattern
}

function Get-TreeItemFilterStatus {
    param(
        [object]$Item,
        [string[]]$Include,
        [string[]]$Exclude,
        [string]$RootPath
    )

    $name = $Item.Name
    $itemFullPath = [System.IO.Path]::GetFullPath($Item.FullPath).TrimEnd('\', '/')

    # 1. Exact Name Exclude Priority
    # Explicit exclusions of a specific name should always win.
    if ($Exclude -contains $name) { return 'Excluded' }

    # 2. Direct Inclusion Check
    if ($Include) {
        foreach ($pattern in $Include) {
            if (Test-TreeItemFilterMatch -Item $Item -Pattern $pattern -RootPath $RootPath) {
                return 'Included'
            }
        }
    }

    # 3. Rescue Check (Structural Visibility for ancestors)
    $isAncestorOfInclusion = $false
    if ($Include) {
        foreach ($pattern in $Include) {
            if ($Item.IsContainer) {
                $filter = ConvertTo-TreeFilterPattern -Pattern $pattern -RootPath $RootPath

                # Check if we are a structural requirement for an absolute path inclusion
                if ($filter.IsPathPattern) {
                    $patternPath = $filter.Pattern
                    if (-not [System.IO.Path]::IsPathRooted($patternPath)) {
                        $base = [string]::IsNullOrWhiteSpace($RootPath) ? $PWD.ProviderPath : $RootPath
                        $patternPath = [System.IO.Path]::Combine($base, $patternPath)
                    }
                    $patternPath = [System.IO.Path]::GetFullPath($patternPath).TrimEnd('\', '/')

                    if ($patternPath.StartsWith($itemFullPath + '\', [System.StringComparison]::OrdinalIgnoreCase)) {
                        $isAncestorOfInclusion = $true
                        break
                    }
                }
                else {
                    # Simple name inclusion rescue: 
                    # If we have children loaded, check if any of them (or their descendants) 
                    # match the inclusion pattern.
                    if ($Item.Children) {
                        function Test-AnyChildMatches {
                            param($Nodes, $Pat, $Root)
                            foreach ($node in $Nodes) {
                                if (Test-TreeItemFilterMatch -Item $node -Pattern $Pat -RootPath $Root) { return $true }
                                if ($node.Children -and (Test-AnyChildMatches -Nodes $node.Children -Pat $Pat -Root $Root)) { return $true }
                            }
                            return $false
                        }

                        if (Test-AnyChildMatches -Nodes $Item.Children -Pat $pattern -Root $RootPath) {
                            $isAncestorOfInclusion = $true
                            break
                        }
                    }
                }
            }
        }
    }

    if ($isAncestorOfInclusion) { return 'Ancestor' }

    # 4. Path-based Exclusion Check
    if ($Exclude) {
        foreach ($pattern in $Exclude) {
            if (Test-TreeItemFilterMatch -Item $Item -Pattern $pattern -RootPath $RootPath) {
                return 'Excluded'
            }
        }
    }

    return 'Default'
}

<#
.SYNOPSIS
    Determines if a TreeItem should be displayed.

.DESCRIPTION
    Test-TreeItemVisible evaluates an item against the current traversal settings (Include, Exclude, 
    HideHidden, etc.) to decide if it should be emitted to the pipeline.

    It implements "structural rescue" logic, where an ancestor directory is kept visible if 
    any of its descendants match an inclusion pattern, even if the directory itself doesn't 
    match or is marked for exclusion.
#>
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

    $status = Get-TreeItemFilterStatus -Item $Item -Include $Include -Exclude $Exclude -RootPath $RootPath

    # Structural ancestors to inclusions are ALWAYS visible, 
    # overriding any potential exclusions for that specific branch node.
    if ($status -eq 'Ancestor' -or $status -eq 'Included') { return $true }
    if ($status -eq 'Excluded') { return $false }

    # Files are subject to directory-only filtering even if they aren't explicitly excluded.
    if ($DirectoryOnly -and -not $Item.IsContainer -and $status -ne 'Included') {
        return $false
    }

    if ($status -eq 'Included' -or $status -eq 'Ancestor') { return $true }

    $isHidden = $false
    if ($HideHidden) {
        $isHidden = $Item.IsHidden -or
                ($Item.Native.FileAttributes -and
                        ($Item.Native.FileAttributes -band [IO.FileAttributes]::Hidden) -ne 0
                )
    }

    $isSystem = $false
    if ($HideSystem) {
        $isSystem = $Item.Native.FileAttributes -and
                ($Item.Native.FileAttributes -band [IO.FileAttributes]::System) -ne 0
    }

    if ($isHidden) { return $false }
    if ($isSystem) { return $false }

    return $true
}

<#
.SYNOPSIS
    Determines if a directory should be traversed.

.DESCRIPTION
    Test-TreeItemRecurse checks if the traversal engine should enter a specific directory. 
    It prunes the search tree based on Exclude patterns, recursion depth, and visibility 
    settings like HideHidden.
#>
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

    if (-not $Item.IsContainer) { return $false }
    if ($Item.IsLink -and -not $FollowLinks) { return $false }

    $status = Get-TreeItemFilterStatus -Item $Item -Include $Include -Exclude $Exclude -RootPath $RootPath

    # If it's excluded, we ONLY recurse if it's an ancestor to an inclusion.
    if ($status -eq 'Excluded') { return $false }
    if ($status -eq 'Included' -or $status -eq 'Ancestor') { return $true }

    # Standard traversal pruning for hidden/system items.
    if ($HideHidden) {
        $isHidden = $Item.IsHidden -or (
        $null -ne $Item.Native.FileAttributes -and
                ($Item.Native.FileAttributes -band [IO.FileAttributes]::Hidden) -ne 0
        )
        if ($isHidden) { return $false }
    }

    if ($HideSystem) {
        $isSystem = $Item.Native.FileAttributes -and
                ($Item.Native.FileAttributes -band [IO.FileAttributes]::System) -ne 0
        if ($isSystem) { return $false }
    }

    return $true
}
