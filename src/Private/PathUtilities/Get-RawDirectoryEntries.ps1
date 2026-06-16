# src/Private/PathUtilities/Get-RawDirectoryEntries.ps1

<#
.SYNOPSIS
    Enumerates directory entries using Win32 FindFirstFile.

.DESCRIPTION
    The Get-RawDirectoryEntries cmdlet uses P/Invoke to call the Win32 FindFirstFile and FindNextFile APIs.
    This provides low-level enumeration of directory contents, matching the ordering and behavior of 
    the classic tree.com utility on Windows.
#>
function Get-RawDirectoryEntries {
    param(
        [string]$Path,
        [int]$Depth = 0
    )

    #
    # Load RawEnum type once
    #
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

    #
    # Enumerate entries
    #
    $entries = [RawEnum]::Enum($Path)

    $dirs  = @()
    $files = @()

    foreach ($e in $entries) {
        $isDir = ($e.dwFileAttributes -band [IO.FileAttributes]::Directory) -ne 0
        $fullPath = Join-Path $Path $e.cFileName

        $native = [PSCustomObject]@{
            Platform = 'Windows'
            FileAttributes = [IO.FileAttributes]$e.dwFileAttributes
        }

        $kind = if ($isDir) { 'Directory' } else { 'File' }
        $link = $null
        $states = [System.Collections.Generic.List[string]]::new()

        if (($e.dwFileAttributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
            $kind = if ($isDir) { 'Junction' } else { 'Symlink' }

            $target = $null
            $targetPath = $null
            $isBroken = $null

            # In raw mode (Win32 API), use Get-Item to retrieve PowerShell's
            # link metadata when available.
            $info = Get-Item -LiteralPath $fullPath -Force -ErrorAction SilentlyContinue
            if ($info -and $info.PSObject.Properties.Match('Target')) {
                $target = $info.Target
            }

            $targetPath = $target
            if ($target -is [array]) {
                $targetPath = $target | Select-Object -First 1
            }

            if (-not [string]::IsNullOrWhiteSpace([string]$targetPath)) {
                $targetText = [string]$targetPath

                $candidateTargetPath = if ([System.IO.Path]::IsPathRooted($targetText)) {
                    $targetText
                }
                else {
                    Join-Path -Path $Path -ChildPath $targetText
                }

                if (-not [string]::IsNullOrWhiteSpace($candidateTargetPath)) {
                    $isBroken = -not (Test-Path -LiteralPath $candidateTargetPath)
                }
            }

            $link = [PSCustomObject]@{
                Type       = if ($isDir) { 'Junction' } else { 'SymbolicLink' }
                Target     = $target
                TargetPath = $targetPath
                IsBroken   = $isBroken
            }

            if ($kind -eq 'Symlink') {
                [void]$states.Add('Symlink')
            }
            elseif ($kind -eq 'Junction') {
                [void]$states.Add('Junction')
            }

            if ($isBroken -eq $true) {
                [void]$states.Add('BrokenLink')
            }
        }

        $item = New-TreeItem `
            -FullPath $fullPath `
            -IsContainer $isDir `
            -Kind $kind `
            -Name $e.cFileName `
            -Native $native `
            -Link $link `
            -Depth $Depth `
            -ParentPath $Path `
            -States $states.ToArray()

        if ($isDir) {
            $dirs += $item
        }
        else {
            $files += $item
        }
    }

    #
    # Return structured result
    #
    [PSCustomObject]@{
        Directories = $dirs
        Files       = $files
    }
}
