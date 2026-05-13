# src\Private\TreeItem.ps1

function New-TreeItem {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $FullPath,

        [Parameter(Mandatory)]
        [bool] $IsDirectory,

        [string] $Name,

        [string] $Type,

        [string[]] $Attributes,

        [bool] $IsSymlink = $false,
        [bool] $IsJunction = $false,

        [object[]] $Children
    )

    # Default values
    if (-not $Name) {
        $Name = Split-Path -Path $FullPath -Leaf
    }

    if (-not $Type) {
        $Type = if ($IsDirectory) { 'Directory' } else { 'File' }
    }

    if (-not $Attributes) {
        $Attributes = @()
    }

    if (-not $Children) {
        $Children = @()
    }

    [PSCustomObject]@{
        PSTypeName  = 'ShowTree.TreeItem'
        Name        = $Name
        FullPath    = $FullPath
        Type        = $Type
        IsDirectory = $IsDirectory
        IsSymlink   = $IsSymlink
        IsJunction  = $IsJunction
        Attributes  = $Attributes
        Children    = $Children
    }
}
