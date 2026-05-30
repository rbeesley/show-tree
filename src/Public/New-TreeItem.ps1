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

    # Compatibility inputs. These are folded into States and are not stored
    # as independent values on the TreeItem.
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

    $legacyStateMap = @{
        Hidden     = $IsHidden
        Executable = $IsExecutable
        ReadOnly   = $IsReadOnly
    }

    foreach ($stateName in $legacyStateMap.Keys) {
        if ($legacyStateMap[$stateName] -eq $true -and -not $resolvedStates.Contains($stateName)) {
            [void] $resolvedStates.Add($stateName)
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

        Length         = $Length -ge 0 ? $Length : $null
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