# src/Private/PathUtilities/Get-VolumeSerialNumber.ps1

<#
.SYNOPSIS
    Retrieves the volume serial number using Win32 API.

.DESCRIPTION
    The Get-VolumeSerialNumber cmdlet calls the Win32 GetVolumeInformation API to retrieve
    the serial number of the volume containing the specified path, formatted to match tree.com.
    Used only in Tree.com compatibility mode.
#>
function Get-VolumeSerialNumber {
    param (
        [string]$Path = "."
    )

    if (-not $PSBoundParameters.ContainsKey('Debug'))
    {
        $DebugPreference = $PSCmdlet.GetVariableValue('DebugPreference')
    }
    if (-not $PSBoundParameters.ContainsKey('Verbose'))
    {
        $VerbosePreference = $PSCmdlet.GetVariableValue('VerbosePreference')
    }

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
