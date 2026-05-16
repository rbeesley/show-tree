# src\Tests\Fixtures\TreeItemFixtures.ps1

function New-FixtureTreeItem {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $Name,
        [string] $ParentPath,
        [bool] $IsDirectory = $false,
        [IO.FileAttributes] $Attributes = 0,
        [object[]] $Children = @(),
        [bool] $IsSymlink = $false,
        [bool] $IsJunction = $false,
        [string] $Target = $null,
        [int] $Depth = 0
    )

    if (-not $ParentPath) {
        $ParentPath = if ($IsWindows) { 'C:\Test' } else { '/tmp/test' }
    }

    $fullPath = Join-Path $ParentPath $Name

    New-TreeItem -FullPath $fullPath `
                 -Name $Name `
                 -IsDirectory $IsDirectory `
                 -Attributes $Attributes `
                 -Children $Children `
                 -IsSymlink $IsSymlink `
                 -IsJunction $IsJunction `
                 -Target $Target `
                 -Depth $Depth `
                 -Parent $ParentPath
}

function New-FixtureTree {
    param(
        [Parameter(Mandatory)]
        [hashtable]$Structure,
        [string]$ParentPath
    )

    if (-not $ParentPath) {
        $ParentPath = if ($IsWindows) { 'C:\Test' } else { '/tmp/test' }
    }

    function BuildFixtureNode($name, $value, $parentPath, $depth = 0) {
        # Case 1: Directory (OrderedDictionary or Hashtable with Children)
        $isDir = $false
        $children = @()
        $attrs = [IO.FileAttributes]0
        $isSymlink = $false
        $isJunction = $false
        $target = $null

        if ($value -is [System.Collections.Specialized.OrderedDictionary]) {
            $isDir = $true
            $children = foreach ($key in $value.Keys) {
                BuildFixtureNode $key $value[$key] (Join-Path $parentPath $name) ($depth + 1)
            }
            $attrs = $attrs -bor [IO.FileAttributes]::Directory
        }
        elseif ($value -is [hashtable]) {
            if ($value.ContainsKey('Attributes')) {
                $attrs = [IO.FileAttributes]$value.Attributes
            }
            
            if ($value.ContainsKey('IsSymlink')) { $isSymlink = $value.IsSymlink }
            if ($value.ContainsKey('IsJunction')) { $isJunction = $value.IsJunction }
            if ($value.ContainsKey('Target')) { $target = $value.Target }

            if ($value.ContainsKey('Children')) {
                $isDir = $true
                $childSource = $value.Children
                if ($childSource -is [hashtable] -or $childSource -is [System.Collections.Specialized.OrderedDictionary]) {
                    $children = foreach ($key in $childSource.Keys) {
                        BuildFixtureNode $key $childSource[$key] (Join-Path $parentPath $name) ($depth + 1)
                    }
                }
            }
            else {
                $isDir = $false
                if ($value.ContainsKey('IsDirectory')) { $isDir = $value.IsDirectory }
            }
            
            if ($isDir -and ($attrs -band [IO.FileAttributes]::Directory) -eq 0) {
                $attrs = $attrs -bor [IO.FileAttributes]::Directory
            }
        }
        else {
            # Simple file ($null)
        }

        return New-FixtureTreeItem -Name $name `
                                   -ParentPath $parentPath `
                                   -IsDirectory:$isDir `
                                   -Attributes $attrs `
                                   -Children $children `
                                   -IsSymlink $isSymlink `
                                   -IsJunction $isJunction `
                                   -Target $target `
                                   -Depth $depth
    }

    $rootName = ($Structure.GetEnumerator() | Select-Object -First 1).Key
    BuildFixtureNode $rootName $Structure[$rootName] $ParentPath 0
}
