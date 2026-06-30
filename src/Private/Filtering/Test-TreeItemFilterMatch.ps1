# src/Private/Filtering/Test-TreeItemFilterMatch.ps1

<#
.SYNOPSIS
    Tests if an item matches a specific glob pattern.

.DESCRIPTION
    Test-TreeItemFilterMatch performs the actual string or path matching for a single 
    pattern. It handles both simple wildcards and complex path-based patterns, 
    accounting for the traversal root path.
#>
function Test-TreeItemFilterMatch
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Item,

        [Parameter(Mandatory)]
        [string]$Pattern,

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

    $filter = ConvertTo-TreeFilterPattern -Pattern $Pattern -RootPath $RootPath

    if ($filter.DirectoryOnly -and -not $Item.IsContainer)
    {
        return $false
    }

    $itemPath = [System.IO.Path]::GetFullPath($Item.FullPath).TrimEnd([System.IO.Path]::DirectorySeparatorChar)

    # If the pattern contains separators, treat it as a path match
    $isPathMatch = $Pattern.Contains([System.IO.Path]::DirectorySeparatorChar)

    if ($isPathMatch)
    {
        # Canonicalize the pattern path
        $patternPath = $filter.Pattern

        # If the pattern is not rooted, we check if it matches as a relative suffix
        # or a specific segment in the path.
        if (-not [System.IO.Path]::IsPathRooted($patternPath))
        {
            $sep = [System.IO.Path]::DirectorySeparatorChar
            $normPattern = $sep + $patternPath.TrimStart($sep)
            $normItem = $sep + $itemPath.Replace($RootPath, '').TrimStart($sep)

            Write-Verbose "    Test-Match (Relative): normItem='$normItem' normPattern='$normPattern'"

            if ($normItem.Contains($normPattern + $sep) -or $normItem.EndsWith($normPattern))
            {
                Write-Verbose "      True"
                return $true
            }
            Write-Verbose "      False"
            return $false
        }

        $patternPath = [System.IO.Path]::GetFullPath($patternPath).TrimEnd([System.IO.Path]::DirectorySeparatorChar)

        $hasWildcard = $patternPath.Contains('*') -or $patternPath.Contains('?')
        if ($hasWildcard)
        {
            Write-Verbose "    Test-Match (Wildcard): itemPath='$itemPath' patternPath='$patternPath'"
            return $itemPath -like $patternPath -or $itemPath -like ($patternPath + [System.IO.Path]::DirectorySeparatorChar + '*')
        }

        Write-Verbose "    Test-Match (Relative): itemPath='$itemPath' patternPath='$patternPath'"
        return $itemPath -eq $patternPath -or $itemPath.StartsWith($patternPath + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase)
    }

    # Name-based match: An item matches if its name matches
    if ($Item.Name -like $filter.Pattern) {
        Write-Verbose "    Test-Match (Name): result='True'"
        return $true
    }

    # Recursive segment check: only for exclusions (where RootPath is provided)
    if ($RootPath) {
        $relPath = $itemPath.Replace($RootPath, '').TrimStart([System.IO.Path]::DirectorySeparatorChar)
        if ($relPath) {
            foreach ($segment in $relPath.Split([System.IO.Path]::DirectorySeparatorChar)) {
                if ($segment -like $filter.Pattern) {
                    Write-Verbose "    Test-Match (Segment): result='True' (matched $segment)"
                    return $true
                }
            }
        }
    }

    Write-Verbose "    Test-Match (Name): result='False'"
    return $false
}
