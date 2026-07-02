# src/Private/Filtering/Get-TreeItemFilterStatus.ps1

<#
.SYNOPSIS
    Determines the filtering status of an item.

.DESCRIPTION
    Get-TreeItemFilterStatus evaluates an item against sets of Include and Exclude patterns. 
    It returns a status of 'Included', 'Excluded', 'Ancestor' (if the item is a required 
    structural parent for a nested inclusion), or 'Default'.
#>
function Get-TreeItemFilterStatus {
    param(
        [object]$Item,
        [string[]]$Include,
        [string[]]$Exclude,
        [string]$RootPath
    )
    
    if (-not $PSBoundParameters.ContainsKey('Debug') -and $PSCmdlet)
    {
        $DebugPreference = $PSCmdlet.GetVariableValue('DebugPreference')
    }
    if (-not $PSBoundParameters.ContainsKey('Verbose') -and $PSCmdlet)
    {
        $VerbosePreference = $PSCmdlet.GetVariableValue('VerbosePreference')
    }

    $name = $Item.Name
    $itemFullPath = [System.IO.Path]::GetFullPath($Item.FullPath).TrimEnd([System.IO.Path]::DirectorySeparatorChar)

    Write-Verbose "Checking Item: $name ($itemFullPath)"

    # 1. Evaluate Exclusions
    $isExcludedByName = $Exclude -contains $name -or $Exclude -contains "$name$([System.IO.Path]::DirectorySeparatorChar)"
    $isExcludedByPath = $false
    if ($Exclude) {
        foreach ($pattern in $Exclude) {
            if (Test-TreeItemFilterMatch -Item $Item -Pattern $pattern -RootPath $RootPath) {
                Write-Verbose "  Excluded by Name: $name"
                $isExcludedByPath = $true
                break
            }
        }
    }

    # 2. Evaluate Inclusions
    $isDirectlyIncluded = $false
    if ($Include) {
        foreach ($pattern in $Include) {
            # When checking inclusions, we do NOT provide RootPath to Test-TreeItemFilterMatch
            # to prevent broad name-only inclusions from matching every child in the tree.
            if (Test-TreeItemFilterMatch -Item $Item -Pattern $pattern -RootPath $RootPath) {
                Write-Verbose "  Included by pattern: $pattern"
                $isDirectlyIncluded = $true
                break
            }
        }
    }

    # 3. Rescue Check (Structural Visibility for ancestors)
    $isAncestorOfInclusion = $false
    if ($Include) {
        foreach ($pattern in $Include) {
            if ($Item.IsContainer) {
                $filter = ConvertTo-TreeFilterPattern -Pattern $pattern -RootPath $RootPath

                # If the pattern contains separators, use efficient prefix matching
                $isPathPattern = $pattern.Contains([System.IO.Path]::DirectorySeparatorChar) -or $pattern.Contains('/')
                Write-Verbose "  Rescue Check pattern: '$($filter.Pattern)' (IsPath: $isPathPattern)"

                if ($isPathPattern) {
                    $patternPath = $filter.Pattern
                    if (-not [System.IO.Path]::IsPathRooted($patternPath)) {
                        $base = [string]::IsNullOrWhiteSpace($RootPath) ? $PWD.ProviderPath : $RootPath
                        $patternPath = [System.IO.Path]::Combine($base, $patternPath)
                    }

                    # Normalize for consistent prefix matching
                    $patternPath = $patternPath.TrimEnd([System.IO.Path]::DirectorySeparatorChar)

                    # Check if current item is a parent of the inclusion path
                    $itemPrefix = $itemFullPath + [System.IO.Path]::DirectorySeparatorChar
                    Write-Verbose "    Prefix Check: itemPrefix='$itemPrefix' vs patternPath='$patternPath'"
                    if ($patternPath.StartsWith($itemPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
                        Write-Verbose "      Ancestor Rescue (Prefix): Item matches prefix of $patternPath"
                        $isAncestorOfInclusion = $true
                        break
                    }

                    # Exact parent check
                    $parentPath = [System.IO.Path]::GetDirectoryName($patternPath)
                    if ($parentPath -and $itemFullPath -eq $parentPath.TrimEnd([System.IO.Path]::DirectorySeparatorChar)) {
                        Write-Verbose "      Ancestor Rescue (Parent): Item is parent of $patternPath"
                        $isAncestorOfInclusion = $true
                        break
                    }
                }
                else {
                    Write-Verbose "    Falling back to Test-Path matching for name pattern: $pattern"
                    # Use Test-Path to see if the inclusion exists anywhere inside the current item
                    if (Test-Path -LiteralPath (Join-Path $Item.FullPath $pattern) -ErrorAction SilentlyContinue) {
                        Write-Verbose "      True"
                        $isAncestorOfInclusion = $true
                        break
                    }
                    Write-Verbose "      False"
                }
            }
        }
    }

    # Priority: Ancestor > ExcludedByName > Included > ExcludedByPath > Default
    if ($isAncestorOfInclusion) { return 'Ancestor' }
    if ($isExcludedByName) { return 'Excluded' }
    if ($isDirectlyIncluded) { return 'Included' }
    if ($isExcludedByPath) { return 'Excluded' }

    return 'Default'
}
