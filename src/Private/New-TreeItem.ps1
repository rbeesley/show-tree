# src\Private\New-TreeItem.ps1

function New-TreeItem {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $FullPath,

        [Parameter(Mandatory)]
        [bool] $IsDirectory,

        [string] $Name,

        [string] $Type,

        [IO.FileAttributes] $Attributes = 0,

        [string] $Parent,

        [int] $Depth = 0,

        [bool] $IsSymlink = $false,
        [bool] $IsJunction = $false,

        [string] $Target,

        [object[]] $Children
    )

    # Default values
    if (-not $Name) {
        $Name = Split-Path -Path $FullPath -Leaf
    }

    if (-not $Type) {
        $Type = if ($IsDirectory) { 'Directory' } else { 'File' }
    }

    if (-not $Children) {
        $Children = @()
    }

    $isHidden = ($Attributes -band [IO.FileAttributes]::Hidden) -ne 0
    $isSystem = ($Attributes -band [IO.FileAttributes]::System) -ne 0

    $localIsWindows = $true
    if ($PSVersionTable.PSEdition -eq 'Core') {
        $localIsWindows = [System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform([System.Runtime.InteropServices.OSPlatform]::Windows)
    }

    # Cross-platform hidden detection (files/dirs starting with '.' on non-Windows)
    if (-not $localIsWindows -and $Name.StartsWith('.')) {
        $isHidden = $true
    }

    $isReparsePoint = ($Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0 -or $IsSymlink -or $IsJunction

    [PSCustomObject]@{
        PSTypeName     = 'ShowTree.TreeItem'
        Name           = $Name
        FullPath       = $FullPath
        Parent         = $Parent
        Type           = $Type
        IsDirectory    = $IsDirectory
        IsSymlink      = $IsSymlink
        IsJunction     = $IsJunction
        IsReparsePoint = $isReparsePoint
        Target         = $Target
        Attributes     = $Attributes
        IsHidden       = $isHidden
        IsSystem       = $isSystem
        Depth          = $Depth
        Children       = $Children
    }
}
