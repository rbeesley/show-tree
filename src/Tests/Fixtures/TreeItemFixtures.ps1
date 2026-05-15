# src\Tests\Fixtures\TreeItemFixtures.ps1

function New-FixtureTreeItem {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $Name,
        [string] $ParentPath = 'C:\Test',
        [bool] $IsDirectory = $false,
        [string[]] $Attributes = @(),
        [object[]] $Children = @(),
        [bool] $IsSymlink = $false,
        [bool] $IsJunction = $false
    )

    $fullPath = Join-Path $ParentPath $Name

    New-TreeItem -FullPath $fullPath `
                 -Name $Name `
                 -IsDirectory $IsDirectory `
                 -Attributes $Attributes `
                 -Children $Children `
                 -IsSymlink $IsSymlink `
                 -IsJunction $IsJunction
}

function New-FixtureTree {
    param(
        [Parameter(Mandatory)]
        [hashtable]$Structure,
        [string]$ParentPath = "C:\Test"
    )

    function BuildFixtureNode($name, $value, $parentPath) {
        # Case 1: Directory (OrderedDictionary or Hashtable with Children)
        $isDir = $false
        $children = @()
        $attrs = @()
        $isSymlink = $false
        $isJunction = $false

        if ($value -is [System.Collections.Specialized.OrderedDictionary]) {
            $isDir = $true
            $children = foreach ($key in $value.Keys) {
                BuildFixtureNode $key $value[$key] (Join-Path $parentPath $name)
            }
            $attrs = @('Directory')
        }
        elseif ($value -is [hashtable]) {
            if ($value.ContainsKey('Attributes')) {
                $attrs = $value.Attributes
            }
            
            if ($value.ContainsKey('IsSymlink')) { $isSymlink = $value.IsSymlink }
            if ($value.ContainsKey('IsJunction')) { $isJunction = $value.IsJunction }

            if ($value.ContainsKey('Children')) {
                $isDir = $true
                $childSource = $value.Children
                if ($childSource -is [hashtable] -or $childSource -is [System.Collections.Specialized.OrderedDictionary]) {
                    $children = foreach ($key in $childSource.Keys) {
                        BuildFixtureNode $key $childSource[$key] (Join-Path $parentPath $name)
                    }
                }
            }
            else {
                $isDir = $false
                if ($value.ContainsKey('IsDirectory')) { $isDir = $value.IsDirectory }
            }
            
            if ($isDir -and 'Directory' -notin $attrs) {
                $attrs += 'Directory'
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
                                   -IsJunction $isJunction
    }

    $rootName = ($Structure.GetEnumerator() | Select-Object -First 1).Key
    BuildFixtureNode $rootName $Structure[$rootName] $ParentPath
}
