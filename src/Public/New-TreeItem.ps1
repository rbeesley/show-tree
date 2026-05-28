# src/Public/New-TreeItem.ps1

function New-TreeItem {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $FullPath,

        [string] $Name,

        [string] $ParentPath,

        [ValidateSet(
            'File',
            'Directory',
            'Symlink',
            'Junction',
            'MountPoint',
            'Socket',
            'Pipe',
            'BlockDevice',
            'CharacterDevice',
            'Device',
            'Other',
            'Unknown'
        )]
        [string] $Kind = 'Unknown',

        [bool] $IsContainer,

        [int] $Depth = 0,

        [object] $IsHidden = $null,
        [object] $IsExecutable = $null,
        [object] $IsReadOnly = $null,

        [long] $Length = -1,

        [datetime] $CreationTime,
        [datetime] $LastWriteTime,
        [datetime] $LastAccessTime,

        [object] $Link,
        [object] $Permissions,
        [object] $Native,

        [object[]] $Children
    )

    if (-not $Name) {
        $Name = Split-Path -Path $FullPath -Leaf
    }

    if (-not $Children) {
        $Children = @()
    }

    if (-not $Link) {
        $Link = [PSCustomObject]@{
            Type       = 'None'
            Target     = $null
            TargetPath = $null
            IsBroken   = $null
        }
    }

    if (-not $Permissions) {
        $Permissions = [PSCustomObject]@{
            Mode     = $null
            Symbolic = $null
            Owner    = $null
            Group    = $null
        }
    }

    if (-not $Native) {
        $Native = [PSCustomObject]@{
            Platform       = $null
            FileAttributes = $null
            Raw            = $null
        }
    }

    $isLink = $Link.Type -and $Link.Type -ne 'None'
    $isLeaf = -not $IsContainer
    $resolvedLength = if ($Length -ge 0) { $Length } else { $null }

    [PSCustomObject]@{
        PSTypeName     = 'ShowTree.TreeItem'

        Name           = $Name
        FullPath       = $FullPath
        ParentPath     = $ParentPath
        Depth          = $Depth

        Kind           = $Kind
        IsContainer    = $IsContainer
        IsLeaf         = $isLeaf
        IsFile         = $Kind -eq 'File'
        IsDirectory    = $Kind -eq 'Directory'

        IsHidden       = $IsHidden
        IsExecutable   = $IsExecutable
        IsReadOnly     = $IsReadOnly

        Length         = $resolvedLength
        CreationTime   = $CreationTime
        LastWriteTime  = $LastWriteTime
        LastAccessTime = $LastAccessTime

        IsLink         = $isLink
        Link           = $Link

        Permissions    = $Permissions
        Native         = $Native

        Children       = $Children
    }
}