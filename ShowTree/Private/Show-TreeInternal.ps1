function Show-TreeInternal {
    [CmdletBinding()]
    param (
        [string]$Path,
        [switch]$Tree,
        [switch]$Listing,
        [int]$MaxDepth,
        [switch]$Colorize,
        [switch]$IncludeFiles,
        [switch]$Gap,
        [switch]$Ascii,
        [int]$CurrentDepth,
        [string]$Prefix,
        [bool]$IsLastParent
    )

    # ANSI color codes
    $esc = [char]27
    $colorReset = $Colorize ? "${esc}[0m" : ""        # Color Reset
    $colorFile = $Colorize ? "${esc}[97m" : ""        # Bright White
    $colorDir = $Colorize ? "${esc}[96m" : ""         # Bright Cyan
    $colorConnector = $Colorize ? "${esc}[90m" : ""   # Dim Gray
    $colorGap = $colorConnector

    if ($CurrentDepth -eq 0) {
        $Path = Get-NormalizedPath -Path $Path
        $NearestExistingParent = Get-NearestExistingParent -Path $Path

        if (-not (Test-Path $Path)) {
            $invalidPath = $true
        }
        
        if ($Tree) {

            $fileSystemLabel = Get-VolumeName -Path $NearestExistingParent
            $serialNumber = Get-VolumeSerialNumber -Path $NearestExistingParent

            Write-Output "Folder PATH listing for volume $fileSystemLabel"
            Write-Output "Volume serial number is $serialNumber"
        }

        Write-Output "${colorDir}$Path${colorReset}"

        if ($invalidPath) {
            Write-Output "Invalid path - \$($Path -Split '\\' | Select-Object -Last 1)"
        }
    }

    if ($MaxDepth -ne -1 -and $CurrentDepth -ge $MaxDepth) {
        return
    }

    if ($Tree) {
        $raw = Get-RawDirectoryEntries -Path $Path
        $dirs = $raw.Directories
        $files = $IncludeFiles ? $raw.Files : @()
    } else {
        $dirs = Get-ChildItem -Path $Path -Directory -ErrorAction SilentlyContinue
        $files = if ($IncludeFiles) { 
            Get-ChildItem -Path $Path -File -ErrorAction SilentlyContinue
        } else {
            @()
        }
    }

    $fileCount = $files.Count
    $dirCount = $dirs.Count

    $noSpan = $false
    if ($Tree -and $dirCount -eq 0) {
        $noSpan = $true
    }

    # Print files first
    for ($j = 0; $j -lt $fileCount; $j++) {
        $file = $files[$j]
        $isLastFile = ($j -eq $fileCount - 1) -and ($dirCount -eq 0)
        $fileConnector = $Listing ?
                            " " :
                            $noSpan ?
                                "    " :
                                $Tree ?
                                    $isLastFile ? # Tree
                                        $Ascii ?
                                            "|   " :
                                            "│   " :
                                        $Ascii ?
                                            "|   " :
                                            "│   " :
                                    $isLastFile ? # Show-Tree
                                        $Ascii ?
                                            "\-- " :
                                            "╙── " :
                                        $Ascii ?
                                            "+-- " :
                                            "╟── "
        Write-Output "${colorGap}${Prefix}${colorConnector}${fileConnector}${colorFile}$($file.Name)${colorReset}"
    }

    if ($invalidPath -or $CurrentDepth -eq 0 -and $dirs.Count -eq 0) {
        if ($Tree) {
            if (-not $invalidPath) {
                Write-Output ""
            }
            Write-Output "No subfolders exist"
        }
        Write-Output ""
        return
    }

    # Add a visual gap only if there are both files and directories
    if ($Gap -and $IncludeFiles -and $fileCount -gt 0 -and $dirCount -gt 0) {
        $gapConnector = $Tree ?
                            $Ascii ? # Tree
                                "|" :
                                "│" :
                            $Ascii ? # Show-Tree
                                "|" :
                                "║"
        Write-Output "${colorGap}${Prefix}${gapConnector}${colorReset}"
    }
    elseif ($Gap -and $IncludeFiles -and $fileCount -gt 0 -and $dirCount -eq 0) {
        Write-Output "${colorGap}${Prefix}${colorReset}"
    }

    # Print directories
    for ($i = 0; $i -lt $dirCount; $i++) {
        $dir = $dirs[$i]
        $isLastDir = ($i -eq $dirCount - 1)
        $dirConnector = $Listing ?
                            " " :
                            $Tree ?
                                $isLastDir ? # Tree
                                    $Ascii ?
                                        "\---" :
                                        "└───" :
                                    $Ascii ?
                                        "+---" :
                                        "├───" :
                                $isLastDir ? # Show-Tree
                                    $Ascii ?
                                        "\== " :
                                        "╚══ " :
                                    $Ascii ?
                                        "+== " :
                                        "╠══ "
        Write-Output "${colorGap}${Prefix}${colorConnector}${dirConnector}${colorDir}$($dir.Name)${colorReset}"
        $newPrefix = $Prefix + ($Listing ?
                                    " " :
                                    $Tree ?
                                        $isLastDir ? # Tree
                                            "    " :
                                            $Ascii ?
                                                "|   " :
                                                "│   " :
                                        $isLastDir ? # Show-Tree
                                            "    " :
                                            $Ascii ?
                                                "|   " :
                                                "║   ")

        # Recursively show contents
        $params = @{
            Path = $dir.FullName
            Tree = $Tree
            Listing = $Listing
            IncludeFiles = $IncludeFiles
            Colorize = $Colorize
            Gap = $Gap
            MaxDepth = $MaxDepth
            CurrentDepth = $CurrentDepth + 1
            Prefix = $newPrefix
            IsLastParent = $isLastDir
            Ascii = $Ascii
        }
        Show-TreeInternal @params

        # Add a gap only if this is the last directory and its parent is not also the last
        if (-not $Tree -and $Gap -and $IncludeFiles -and $isLastDir -and -not $IsLastParent -and $CurrentDepth -gt 0) {
            Write-Output "${colorGap}${Prefix}${colorReset}"
        }
    }

    # Add a final newline only after the top-level call completes
    if (-not $Tree -and $CurrentDepth -eq 0) {
        Write-Output ""
    }
}

# Normalize path to match actual casing on filesystem
function Get-NormalizedPath {
    param (
        [string]$Path = "."
    )

    $absPath = [System.IO.Path]::GetFullPath($Path)

    # Remove trailing slash unless it's a root
    if ($absPath.Length -gt 3 -and $absPath.EndsWith("\")) {
        $absPath = $absPath.TrimEnd('\')
    }

    $segments = $absPath -split '\\'
    $normalized = @()
    $current = $segments[0] + "\"

    $normalized += $segments[0]

    for ($i = 1; $i -lt $segments.Count; $i++) {
        $segment = $segments[$i]
        try {
            $entries = Get-ChildItem -LiteralPath $current | Select-Object -ExpandProperty Name
            $match = $entries | Where-Object { $_.ToLower() -eq $segment.ToLower() }
            if ($match) {
                $normalized += $match
                $current = Join-Path $current $match
            } else {
                $normalized += $segment
                $current = Join-Path $current $segment
            }
        } catch {
            $normalized += $segment
            $current = Join-Path $current $segment
        }
    }

    return ($normalized -join '\')
}

function Get-NearestExistingParent {
    param (
        [string]$Path
    )

    $current = [System.IO.Path]::GetFullPath($Path)

    while (-not (Test-Path $current)) {
        $parent = [System.IO.Directory]::GetParent($current)
        if ($null -eq $parent) {
            return $null  # Reached the root and nothing exists
        }
        $current = $parent.FullName
    }

    return $current
}

function Get-VolumeName {
    param (
        [string]$Path = "."
    )

    $driveLetter = (Get-Item $Path).PSDrive.Name
    $volume = Get-Volume -DriveLetter $driveLetter

    return $volume.FileSystemLabel    
}

# Get volume serial number
function Get-VolumeSerialNumber {
    param (
        [string]$Path = "."
    )

    # --- Win32 GetVolumeInformation (all filesystems) ---
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

    $serial = 0
    $null1 = 0
    $null2 = 0
    $volName = New-Object System.Text.StringBuilder 261
    $fsName = New-Object System.Text.StringBuilder 261

    [VolumeInfo]::GetVolumeInformation(
        $root, $volName, $volName.Capacity,
        [ref]$serial, [ref]$null1, [ref]$null2,
        $fsName, $fsName.Capacity
    ) | Out-Null

    $serialHigh = ($serial -shr 16)
    $serialLow  = ($serial -band 0xFFFF)

    return "{0:X4}-{1:X4}" -f $serialHigh, $serialLow
}

# Get the Directory Entires via Win32 calls directly
function Get-RawDirectoryEntries {
    param([string]$Path)

    if (-not ([System.Management.Automation.PSTypeName]'RawEnum').Type) {
        $definition = @"
using System;
using System.IO;
using System.Runtime.InteropServices;
using System.Collections.Generic;

public class RawEnum {
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    public struct WIN32_FIND_DATA {
        public uint dwFileAttributes;
        public System.Runtime.InteropServices.ComTypes.FILETIME ftCreationTime;
        public System.Runtime.InteropServices.ComTypes.FILETIME ftLastAccessTime;
        public System.Runtime.InteropServices.ComTypes.FILETIME ftLastWriteTime;
        public uint nFileSizeHigh;
        public uint nFileSizeLow;
        public uint dwReserved0;
        public uint dwReserved1;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 260)]
        public string cFileName;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 14)]
        public string cAlternateFileName;
    }

    [DllImport("kernel32.dll", CharSet = CharSet.Unicode)]
    static extern IntPtr FindFirstFile(string lpFileName, out WIN32_FIND_DATA lpFindFileData);

    [DllImport("kernel32.dll", CharSet = CharSet.Unicode)]
    static extern bool FindNextFile(IntPtr hFindFile, out WIN32_FIND_DATA lpFindFileData);

    [DllImport("kernel32.dll")]
    static extern bool FindClose(IntPtr hFindFile);

    public static IEnumerable<WIN32_FIND_DATA> Enum(string path) {
        WIN32_FIND_DATA data;
        IntPtr handle = FindFirstFile(Path.Combine(path, "*"), out data);
        if (handle == new IntPtr(-1)) yield break;

        do {
            string name = data.cFileName;
            if (name != "." && name != "..")
                yield return data;
        }
        while (FindNextFile(handle, out data));

        FindClose(handle);
    }
}
"@
        Add-Type -TypeDefinition $definition -ErrorAction SilentlyContinue | Out-Null
    }

    $entries = [RawEnum]::Enum($Path)

    $dirs = @()
    $files = @()

    foreach ($e in $entries) {
        $full = Join-Path $Path $e.cFileName

        $attrs = $e.dwFileAttributes

        # Skip hidden and system items to match tree.com
        if ($attrs -band [IO.FileAttributes]::Hidden) { continue }
        if ($attrs -band [IO.FileAttributes]::System) { continue }

        $isDir = ($e.dwFileAttributes -band [IO.FileAttributes]::Directory) -ne 0

        # Write-Host "FULL=[$full]"
        if ($isDir) {
            $dirs += [System.IO.DirectoryInfo]::new($full)
        } else {
            $files += [System.IO.FileInfo]::new($full)
        }
    }

    return [PSCustomObject]@{
        Directories = $dirs
        Files       = $files
    }
}
