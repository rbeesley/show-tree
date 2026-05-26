# src\Tests\Fixtures\TreeItemFixtures.ps1

function New-FixtureTreeItem {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $Name,
        [string] $ParentPath,
        [bool] $IsDirectory = $false,
        [IO.FileAttributes] $FileAttributes = 0,
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
    
    $kind = if ($IsDirectory) { 'Directory' } else { 'File' }
    if ($IsSymlink) { $kind = 'Symlink' }
    if ($IsJunction) { $kind = 'Junction' }

    $link = if ($IsSymlink -or $IsJunction) {
        [PSCustomObject]@{
            Type = if ($IsSymlink) { 'SymbolicLink' } else { 'Junction' }
            Target = $Target
            TargetPath = $Target
            IsBroken = $false
        }
    } else {
        $null
    }

    $native = [PSCustomObject]@{
        Platform = if ($IsWindows) { 'Windows' } else { 'Unix' }
        FileAttributes = $FileAttributes
    }

    New-TreeItem -FullPath $fullPath `
                 -Name $Name `
                 -Kind $kind `
                 -IsContainer $IsDirectory `
                 -Children $Children `
                 -Link $link `
                 -Native $native `
                 -Depth $Depth `
                 -ParentPath $ParentPath
}

function New-FixtureTree {
    param(
        [Parameter(Mandatory)]
        [System.Collections.IDictionary]$Structure,
        [string]$ParentPath
    )

    if ($Structure -is [hashtable] -and 
        $Structure -isnot [System.Collections.Specialized.OrderedDictionary]) {
        throw "New-FixtureTree requires an ordered dictionary. Use [ordered]@{ ... } for deterministic fixture order."
    }
    
    if (-not $ParentPath) {
        $ParentPath = if ($IsWindows) { 'C:\Test' } else { '/tmp/test' }
    }

    function BuildFixtureNode($name, $value, $parentPath, $depth = 0) {
        # Defaults
        $isDir      = $false
        $children   = @()
        $kind       = 'Unknown'
        $isHidden   = $null
        $isExec     = $null
        $isRO       = $null
        $length     = -1
        $ctime      = $null
        $mtime      = $null
        $atime      = $null
        $link       = $null
        $perms      = $null
        $native     = $null

        #
        # CASE 1 — Directory (OrderedDictionary)
        #
        if ($value -is [System.Collections.Specialized.OrderedDictionary]) {
            $isDir = $true
            $kind  = 'Directory'

            $children = foreach ($key in $value.Keys) {
                BuildFixtureNode $key $value[$key] (Join-Path $parentPath $name) ($depth + 1)
            }
        }

        #
        # CASE 2 — Node descriptor (file OR directory)
        #
        elseif ($value -is [hashtable]) {

            # Generic TreeItem properties
            if ($value.ContainsKey('Kind'))           { $kind       = $value.Kind }
            if ($value.ContainsKey('IsHidden'))       { $isHidden   = $value.IsHidden }
            if ($value.ContainsKey('IsExecutable'))   { $isExec     = $value.IsExecutable }
            if ($value.ContainsKey('IsReadOnly'))     { $isRO       = $value.IsReadOnly }
            if ($value.ContainsKey('Length'))         { $length     = $value.Length }
            if ($value.ContainsKey('CreationTime'))   { $ctime      = $value.CreationTime }
            if ($value.ContainsKey('LastWriteTime'))  { $mtime      = $value.LastWriteTime }
            if ($value.ContainsKey('LastAccessTime')) { $atime      = $value.LastAccessTime }
            if ($value.ContainsKey('Permissions'))    { $perms      = $value.Permissions }
            if ($value.ContainsKey('Native'))         { $native     = $value.Native }

            # Link object
            if ($value.ContainsKey('IsSymlink') -or $value.ContainsKey('IsJunction') -or $value.ContainsKey('Target')) {
                $kind = if ($value.IsSymlink) { 'Symlink' }
                        elseif ($value.IsJunction) { 'Junction' }
                        else { $kind }

                $link = [PSCustomObject]@{
                    Type       = $kind
                    Target     = $value.Target
                    TargetPath = $value.Target
                    IsBroken   = $false
                }
            }

            # Directory descriptor
            if ($value.ContainsKey('Children')) {
                $isDir = $true
                $kind  = if ($kind -eq 'Unknown') { 'Directory' } else { $kind }

                $childSource = $value.Children
                if ($childSource -is [System.Collections.IDictionary]) {
                    $children = foreach ($key in $childSource.Keys) {
                        BuildFixtureNode $key $childSource[$key] (Join-Path $parentPath $name) ($depth + 1)
                    }
                }
            }
        }

        #
        # CASE 3 — Simple file ($null)
        #
        else {
            $kind = 'File'
        }

        #
        # Build the TreeItem
        #
        $fullPath = Join-Path $parentPath $name

        function Build-TreeItemSplat {
            param(
                [string] $Name,
                [string] $ParentPath,
                [int]    $Depth,
                [hashtable] $Descriptor,
                [object[]] $Children
            )

            $fullPath = Join-Path $ParentPath $Name

            $splat = @{
                FullPath    = $fullPath
                Name        = $Name
                ParentPath  = $ParentPath
                Depth       = $Depth
                Children    = $Children
            }

            # Only add keys that exist AND are not $null
            foreach ($key in @(
                'Kind','IsContainer','IsHidden','IsExecutable','IsReadOnly',
                'Length','CreationTime','LastWriteTime','LastAccessTime',
                'Link','Permissions','Native'
            )) {
                if ($Descriptor.ContainsKey($key) -and $null -ne $Descriptor[$key]) {
                    $splat[$key] = $Descriptor[$key]
                }
            }

            return $splat
        }

        $descriptor = @{}

        # Fill descriptor with only the values you discovered
        if ($kind -ne 'Unknown')     { $descriptor.Kind = $kind }
        if ($isDir)                  { $descriptor.IsContainer = $true }
        if ($null -ne $isHidden)     { $descriptor.IsHidden = $isHidden }
        if ($null -ne $isExec)       { $descriptor.IsExecutable = $isExec }
        if ($null -ne $isRO)         { $descriptor.IsReadOnly = $isRO }
        if ($length -ge 0)           { $descriptor.Length = $length }
        if ($ctime)                  { $descriptor.CreationTime = $ctime }
        if ($mtime)                  { $descriptor.LastWriteTime = $mtime }
        if ($atime)                  { $descriptor.LastAccessTime = $atime }
        if ($link)                   { $descriptor.Link = $link }
        if ($perms)                  { $descriptor.Permissions = $perms }
        if ($native)                 { $descriptor.Native = $native }

        # Build the splat
        $splat = Build-TreeItemSplat `
            -Name $name `
            -ParentPath $parentPath `
            -Depth $depth `
            -Descriptor $descriptor `
            -Children $children

        # Call New-TreeItem with only meaningful parameters
        return New-TreeItem @splat
    }

    foreach ($key in $Structure.Keys) {
        BuildFixtureNode $key $Structure[$key] $ParentPath 0
    }
}
