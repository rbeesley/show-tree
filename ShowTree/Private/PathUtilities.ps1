# ShowTree\Private\PathUtilities.ps1

#region Path Utilities
<#
.SYNOPSIS
    Enumerates all set file attributes on an item.

.DESCRIPTION
    Used by Get-ItemStyle to apply attribute overlays.
#>
function Get-SetFileAttributes {
    param([IO.FileAttributes]$Attributes)

    foreach ($flag in [System.Enum]::GetValues([IO.FileAttributes])) {
        if ($Attributes -band $flag) {
            $flag
        }
    }
}

<#
.SYNOPSIS
    Normalizes a path to match actual filesystem casing.

.DESCRIPTION
    Walks each segment and resolves its real casing using Get-ChildItem.
    Ensures consistent display even when user input is lowercase/mixed.
#>
function Get-NormalizedPath {
    param([string]$Path = ".")

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
            $entries = Get-ChildItem -LiteralPath $current -ErrorAction Stop | Select-Object -ExpandProperty Name
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
            $current     = Join-Path $current $segment -ErrorAction Stop
        }
    }

    ($normalized -join '\')
}

<#
.SYNOPSIS
    Finds the nearest existing parent directory.

.DESCRIPTION
    Used for Tree.com header generation when the target path
    does not fully exist.
#>
function Get-NearestExistingParent {
    param([string]$Path)

    $current = [System.IO.Path]::GetFullPath($Path)

    while (-not (Test-Path $current)) {
        $parent = [System.IO.Directory]::GetParent($current)
        if ($null -eq $parent) {
            return $null
        }
        $current = $parent.FullName
    }

    $current
}

<#
.SYNOPSIS
    Returns the filesystem label for a drive.

.DESCRIPTION
    Used only in Tree.com compatibility mode.
#>
function Get-VolumeName {
    param([string]$Path = ".")

    $driveLetter = (Get-Item $Path).PSDrive.Name
    $volume      = Get-Volume -DriveLetter $driveLetter
    $volume.FileSystemLabel
}

<#
.SYNOPSIS
    Retrieves the volume serial number using Win32 API.

.DESCRIPTION
    Matches Tree.com output exactly.
#>
function Get-VolumeSerialNumber {
    param (
        [string]$Path = "."
    )

    if (-not ([System.Management.Automation.PSTypeName]'VolumeInfo').Type) {
        $definition = @"
using System;
using System.Runtime.InteropServices;

public class VolumeInfo {
    [DllImport("kernel32.dll", CharSet = CharSet.Auto)]
    public static extern bool GetVolumeInformation(
        string lpRootPathName,
        System.Text.StringBuilder lpVolumeNameBuffer,
        int nVolumeNameSize,
        out uint lpVolumeSerialNumber,
        out uint lpMaximumComponentLength,
        out uint lpFileSystemFlags,
        System.Text.StringBuilder lpFileSystemNameBuffer,
        int nFileSystemNameSize);
}
"@
        Add-Type -TypeDefinition $definition -ErrorAction SilentlyContinue | Out-Null
    }

    $root = [System.IO.Path]::GetPathRoot((Resolve-Path $Path).Path)

    $serial  = 0
    $null1   = 0
    $null2   = 0
    $volName = New-Object System.Text.StringBuilder 261
    $fsName  = New-Object System.Text.StringBuilder 261

    [VolumeInfo]::GetVolumeInformation(
        $root, $volName, $volName.Capacity,
        [ref]$serial, [ref]$null1, [ref]$null2,
        $fsName, $fsName.Capacity
    ) | Out-Null

    $serialHigh = ($serial -shr 16)
    $serialLow  = ($serial -band 0xFFFF)

    "{0:X4}-{1:X4}" -f $serialHigh, $serialLow
}
#endregion