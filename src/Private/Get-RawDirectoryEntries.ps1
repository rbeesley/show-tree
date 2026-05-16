# src\Private\Get-RawDirectoryEnumeration.ps1

<#
.SYNOPSIS
    Enumerates directory entries using Win32 FindFirstFile.

.DESCRIPTION
    Used in Tree.com mode to match exact ordering and behavior.
    Returns PSCustomObject with:
      • Directories = [...]
      • Files       = [...]
#>
function Get-RawDirectoryEntries {
    param([string]$Path)

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

        $item = New-TreeItem `
            -FullPath $fullPath `
            -IsDirectory $isDir `
            -Name $e.cFileName `
            -Attributes $e.dwFileAttributes

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
