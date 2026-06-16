# src/Public/Get-TreeItem.ps1

<#
.SYNOPSIS
    Streams tree traversal records for a path.

.DESCRIPTION
    The Get-TreeItem cmdlet resolves a path and performs a depth-first traversal of its children.
    It emits ShowTree.TreeRecord objects that contain both the item information and layout metadata
    required for hierarchical rendering.

.PARAMETER Path
    The path to traverse. Default is '.'.

.PARAMETER Depth
    The maximum depth to traverse. -1 for unlimited.

.PARAMETER ProviderMode
    The provider to use for enumerating items ('PowerShell' or 'Win32').
    'Win32' is faster on Windows but may have different behavior for certain file types.

.PARAMETER FollowLinks
    If set, follows symbolic links and junctions during traversal.

.PARAMETER Include
    Filters items to include based on glob patterns.

.PARAMETER Exclude
    Filters items to exclude based on glob patterns.

.PARAMETER HideHidden
    If set, hides hidden files and directories.

.PARAMETER HideSystem
    If set, hides system files and directories.

.PARAMETER DirectoryOnly
    If set, only directories are included in the traversal.

.EXAMPLE
    Get-TreeItem -Path C:\Source -Depth 2 | Format-Tree
    Retrieves items from C:\Source up to 2 levels deep and formats them.

.LINK
    Invoke-TreeTraversal
    Format-Tree
#>
function Get-TreeItem {
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [string] $Path = '.',

        [int] $Depth = -1,

        [ValidateSet('PowerShell', 'Win32')]
        [string] $ProviderMode = 'PowerShell',

        [switch] $FollowLinks,

        [string[]] $Include,
        [string[]] $Exclude,

        [switch] $HideHidden,
        [switch] $HideSystem,
        [switch] $DirectoryOnly
    )

    $resolvedPathInfo = Resolve-Path -LiteralPath $Path -ErrorAction SilentlyContinue

    $resolvedPath = if ($resolvedPathInfo) {
        if ($resolvedPathInfo.PSObject.Properties.Match('ProviderPath')) {
            $resolvedPathInfo.ProviderPath
        }
        else {
            $resolvedPathInfo.Path
        }
    }
    else {
        $Path
    }

    $provider = New-TreeChildProvider -ProviderMode $ProviderMode

    $traversalDepth = if ($Depth -eq -1) {
        -1
    }
    elseif ($Depth -le 0) {
        0
    }
    else {
        $Depth - 1
    }

    Invoke-TreeTraversal `
        -Path $resolvedPath `
        -RootPath $resolvedPath `
        -MaxDepth $traversalDepth `
        -CurrentDepth 0 `
        -Provider $provider `
        -Include $Include `
        -Exclude $Exclude `
        -HideHidden:$HideHidden `
        -HideSystem:$HideSystem `
        -DirectoryOnly:$DirectoryOnly `
        -FollowLinks:$FollowLinks
}
