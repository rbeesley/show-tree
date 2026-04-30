# ShowTree\Private\PathUtilities.ps1

#region Path Utilities
<#
.SYNOPSIS
    Resolves a user-supplied path into a fully qualified provider path with
    correct caller-relative behavior, normalization, and mode-specific error handling.
.DESCRIPTION
    Resolve-TreePath converts user input (relative paths, absolute paths, and
    mixed-case paths) into a canonical provider path suitable for tree rendering.

    The function performs three key operations:

      • Caller-relative resolution  
        Relative paths such as '.', '..', and '.\foo' are resolved against the
        caller's working directory, not the module's import location.

      • Normalization  
        The resulting path is normalized segment-by-segment to match actual
        filesystem casing and to collapse constructs like '..' and redundant
        separators.

      • Mode-specific error behavior  
        In Normal and List modes, nonexistent paths produce a PowerShell-style
        ItemNotFound error.  
        In Tree mode, nonexistent paths are returned verbatim so that the caller
        can reproduce tree.com’s error messages exactly.

    The returned value is always a fully qualified provider path unless the
    path does not exist and Tree mode is active.
#>
function Resolve-TreePath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [ValidateSet('Normal','Tree','List')]
        [string]$Mode = 'Normal'
    )

    try {
        # Caller’s working directory, not module’s
        $cwd = $ExecutionContext.SessionState.Path.CurrentLocation.ProviderPath

        if (-not [System.IO.Path]::IsPathRooted($Path)) {
            $Path = Join-Path -Path $cwd -ChildPath $Path
        }

        # Normalize casing/segments
        $Path = Get-NormalizedPath -Path $Path -ErrorAction Stop

        # Resolve to provider path
        $resolved = Resolve-Path -LiteralPath $Path -ErrorAction Stop
        return $resolved.ProviderPath
    }
    catch {
        if ($Mode -ne 'Tree') {
            $msg = "Cannot find path '$Path' because it does not exist."
            $exception = New-Object System.Management.Automation.ItemNotFoundException $msg
            $category  = [System.Management.Automation.ErrorCategory]::ObjectNotFound

            $errorRecord = New-Object System.Management.Automation.ErrorRecord `
                $exception,
                'ItemNotFound',
                $category,
                $Path

            $PSCmdlet.WriteError($errorRecord)
            return $null
        }

        return $Path
    }
}

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