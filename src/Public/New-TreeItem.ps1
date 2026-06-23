# src/Public/New-TreeItem.ps1

<#
.SYNOPSIS
    Creates a new ShowTree.TreeItem object.

.DESCRIPTION
    The New-TreeItem cmdlet is a factory function for creating ShowTree.TreeItem objects.
    These objects represent files, directories, or other filesystem items in a tree traversal,
    capturing metadata like kind, states (hidden, readonly, etc.), and link information.

.PARAMETER FullPath
    The absolute path to the item.

.PARAMETER Name
    The leaf name of the item. Defaults to the leaf part of FullPath.

.PARAMETER ParentPath
    The path to the parent directory.

.PARAMETER Kind
    The kind of item (e.g., 'File', 'Directory', 'Symlink').

.PARAMETER IsContainer
    True if the item is a directory or other container.

.PARAMETER Depth
    The depth of the item in the tree relative to the root.

.PARAMETER Length
    The size of the item in bytes.

.PARAMETER CreationTime
    The creation time of the item.

.PARAMETER LastWriteTime
    The last write time of the item.

.PARAMETER LastAccessTime
    The last access time of the item.

.PARAMETER Link
    An object containing link information (Type, Target, TargetPath, IsBroken).

.PARAMETER Permissions
    An object containing permission information (Mode, Symbolic, Owner, Group).

.PARAMETER Native
    An object containing native platform information.

.PARAMETER States
    An array of states associated with the item (e.g., 'Hidden', 'Archive', 'System').

.PARAMETER Children
    An array of child TreeItem objects.

.EXAMPLE
    New-TreeItem -FullPath "C:\test.txt" -Kind File -IsContainer $false
    Creates a basic TreeItem for a file.

.LINK
    Get-TreeItem
#>
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

        [long] $Length = -1,

        [datetime] $CreationTime,
        [datetime] $LastWriteTime,
        [datetime] $LastAccessTime,

        [object] $Link,
        [object] $Permissions,
        [object] $Native,
        [string[]] $States,

        [object[]] $Children
    )

    if ([string]::IsNullOrEmpty($Name)) {
        $Name = Split-Path -Path $FullPath -Leaf
    }

    $Children ??= @()

    $Link ??= [PSCustomObject]@{
        Type       = 'None'
        Target     = $null
        TargetPath = $null
        IsBroken   = $null
    }

    $Permissions ??= [PSCustomObject]@{
        Mode     = $null
        Symbolic = $null
        Owner    = $null
        Group    = $null
    }

    $Native ??= [PSCustomObject]@{
        Platform       = $null
        FileAttributes = $null
        Raw            = $null
    }

    $resolvedStates = [System.Collections.Generic.List[string]]::new()

    foreach ($state in @($States)) {
        if ($state -and -not $resolvedStates.Contains($state)) {
            [void] $resolvedStates.Add($state)
        }
    }

    foreach ($stateName in @($Kind)) {
        if ($stateName -in @('Symlink', 'Junction') -and -not $resolvedStates.Contains($stateName)) {
            [void] $resolvedStates.Add($stateName)
        }
    }

    $treeItem = [PSCustomObject]@{
        PSTypeName     = 'ShowTree.TreeItem'

        Name           = $Name
        FullPath       = $FullPath
        ParentPath     = $ParentPath
        Depth          = $Depth

        Kind           = $Kind
        IsContainer    = $IsContainer

        Length         = ($Length -ge 0) ? $Length : $null
        CreationTime   = $CreationTime
        LastWriteTime  = $LastWriteTime
        LastAccessTime = $LastAccessTime

        Link           = $Link

        Permissions    = $Permissions
        Native         = $Native
        States         = $resolvedStates.ToArray()

        Children       = $Children
    }

    $treeItem | Add-Member -MemberType ScriptProperty -Name IsLeaf -Value {
        -not $this.IsContainer
    }

    $treeItem | Add-Member -MemberType ScriptProperty -Name IsFile -Value {
        $this.Kind -eq 'File'
    }

    $treeItem | Add-Member -MemberType ScriptProperty -Name IsDirectory -Value {
        $this.Kind -eq 'Directory'
    }

    $treeItem | Add-Member -MemberType ScriptProperty -Name IsHidden -Value {
        $this.States -contains 'Hidden'
    }

    $treeItem | Add-Member -MemberType ScriptProperty -Name IsExecutable -Value {
        $this.States -contains 'Executable'
    }

    $treeItem | Add-Member -MemberType ScriptProperty -Name IsReadOnly -Value {
        $this.States -contains 'ReadOnly'
    }

    $treeItem | Add-Member -MemberType ScriptProperty -Name IsLink -Value {
        $this.Link.Type -and $this.Link.Type -ne 'None'
    }

    $treeItem
}