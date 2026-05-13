# src\Private\PathUtilities\Get-NormalizedPath.ps1

<#
.SYNOPSIS
    Normalizes a path to match actual filesystem casing.

.DESCRIPTION
    Walks each segment and resolves its real casing using Get-ChildItem.
    Ensures consistent display even when user input is lowercase/mixed.
#>
function Get-NormalizedPath {
    param([string]$Path)

    # Assume absolute path
    $absPath = [System.IO.Path]::GetFullPath($Path)

    # Trim trailing slash unless root
    if ($absPath.Length -gt 3 -and $absPath.EndsWith("\")) {
        $absPath = $absPath.TrimEnd('\')
    }

    $segments   = $absPath -split '\\'
    $normalized = @()
    $current    = $segments[0] + "\"

    $normalized += $segments[0]

    for ($i = 1; $i -lt $segments.Count; $i++) {
        $segment = $segments[$i]

        try {
            $entries = Get-ChildItem -LiteralPath $current -ErrorAction Stop |
                       Select-Object -ExpandProperty Name
            $match   = $entries | Where-Object { $_.ToLower() -eq $segment.ToLower() }

            if ($match) {
                $normalized += $match
                $current     = Join-Path $current $match
            }
            else {
                $normalized += $segment
                $current     = Join-Path $current $segment
            }
        }
        catch {
            # Parent doesn't exist — keep original casing
            $normalized += $segment
            $current     = Join-Path $current $segment
        }
    }

    ($normalized -join '\')
}