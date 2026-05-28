# src/Private/TestItemPredicates.ps1

function Test-TreeItemVisible {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Item,

        [string[]]$Include,
        [string[]]$Exclude,

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
            if ($name -like $pattern) {
                $isIncludedGlob = $true
                break
            }
        }
    }

    $isExcludedGlob = $false
    if (-not $isExcludedExact -and $Exclude) {
        foreach ($pattern in $Exclude) {
            if ($name -like $pattern) {
                $isExcludedGlob = $true
                break
            }
        }
    }

    $isHidden = $false
    if ($HideHidden) {
        $isHidden = $Item.IsHidden -eq $true -or (
            $null -ne $Item.Native.FileAttributes -and
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
            if ($name -like $pattern) {
                # Check if it's rescued by a glob include
                $isRescued = $false
                if ($Include) {
                    foreach ($incPattern in $Include) {
                        if ($name -like $incPattern) {
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
