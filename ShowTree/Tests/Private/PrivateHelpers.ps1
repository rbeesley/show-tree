# ShowTree\Tests\Private\PrivateHelpers.ps1

function New-TestItem {
    param(
        [string]$Name,
        [string]$ParentPath = "C:\Test",
        [IO.FileAttributes]$Attributes = [IO.FileAttributes]::Normal,
        [bool]$IsDirectory = $false,
        [array]$Children = @()
    )

    $fullPath = Join-Path $ParentPath $Name

    $obj = [pscustomobject]@{
        Name          = $Name
        FullName      = $fullPath
        Attributes    = $Attributes
        PSIsContainer = $IsDirectory
        Children      = $Children
    }

    return $obj
}

function New-TestTree {
    param(
        [Parameter(Mandatory)]
        [hashtable]$Structure,
        [string]$ParentPath = "C:\Test"
    )

    function BuildNode($name, $value, $parentPath) {

        # Case 1: Directory (OrderedDictionary)
        if ($value -is [System.Collections.Specialized.OrderedDictionary]) {
            $children = foreach ($key in $value.Keys) {
                BuildNode $key $value[$key] (Join-Path $parentPath $name)
            }

            return New-TestItem -Name $name `
                                -ParentPath $parentPath `
                                -IsDirectory:$true `
                                -Attributes ([IO.FileAttributes]::Directory) `
                                -Children $children
        }

        # Case 2: File or directory with metadata
        if ($value -is [hashtable]) {

            $attrs = [IO.FileAttributes]::Normal
            if ($value.ContainsKey('Attributes')) {
                $attrs = [IO.FileAttributes]::$($value.Attributes)
            }

            $isDir = $value.ContainsKey('Children')

            if ($isDir) {
                $children = foreach ($key in $value.Children.Keys) {
                    BuildNode $key $value.Children[$key] (Join-Path $parentPath $name)
                }

                return New-TestItem -Name $name `
                                    -ParentPath $parentPath `
                                    -IsDirectory:$true `
                                    -Attributes $attrs `
                                    -Children $children
            }
            else {
                return New-TestItem -Name $name `
                                    -ParentPath $parentPath `
                                    -IsDirectory:$false `
                                    -Attributes $attrs
            }
        }

        # Case 3: Simple file ($null)
        return New-TestItem -Name $name `
                            -ParentPath $parentPath `
                            -IsDirectory:$false `
                            -Attributes ([IO.FileAttributes]::Normal)
    }

    $rootName = ($Structure.GetEnumerator() | Select-Object -First 1).Key
    BuildNode $rootName $Structure[$rootName] $ParentPath
}

function Convert-TestTreeToRaw {
    param(
        [Parameter(Mandatory)]
        $Root,
        [Parameter(Mandatory)]
        [string]$Path
    )

    $node = Find-TestNodeByPath -Root $Root -Path $Path
    if ($null -eq $node) {
        return [pscustomobject]@{
            Files       = @()
            Directories = @()
        }
    }

    $files = @()
    $dirs  = @()

    foreach ($child in $node.Children) {
        if ($child.PSIsContainer) {
            $dirs += $child
        }
        else {
            $files += $child
        }
    }

    [pscustomobject]@{
        Files       = $files
        Directories = $dirs
    }
}

function Find-TestNodeByPath {
    param(
        [Parameter(Mandatory)]
        $Root,
        [Parameter(Mandatory)]
        [string]$Path
    )

    if ($Root.FullName -eq $Path) {
        return $Root
    }

    foreach ($child in $Root.Children) {
        if ($child.PSIsContainer) {
            $found = Find-TestNodeByPath -Root $child -Path $Path
            if ($null -ne $found) {
                return $found
            }
        }
        elseif ($child.FullName -eq $Path) {
            return $child
        }
    }

    return $null
}
