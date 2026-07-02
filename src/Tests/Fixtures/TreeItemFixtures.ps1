# src/Tests/Fixtures/TreeItemFixtures.ps1

function New-FixtureTreeItem {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $Name,
        [string] $ParentPath,
        [int] $Depth = 0,
        [hashtable] $Metadata = @{}
    )

    if (-not $ParentPath) {
        $ParentPath = $IsWindows ? 'C:\Test' : '/tmp/test'
    }

    $fullPath = Join-Path $ParentPath $Name

    # 1. Determine Kind and Container status
    $isContainer = $Metadata.IsContainer -eq $true -or $Metadata.IsDirectory -eq $true
    $kind = $Metadata.Kind ? $Metadata.Kind : ($isContainer ? 'Directory' : 'File')
    
    if ($Metadata.IsSymlink)  { $kind = 'Symlink' }
    if ($Metadata.IsJunction) { $kind = 'Junction'; $isContainer = $true }
    if ($kind -eq 'Directory') { $isContainer = $true }

    # 2. Build Link object
    $link = $null
    if ($Metadata.ContainsKey('Target')) {
        $link = [PSCustomObject]@{
            Type = ($kind -eq 'Junction') ? 'Junction' : 'SymbolicLink'
            Target = $Metadata.Target; TargetPath = $Metadata.Target; IsBroken = $false
        }
    }

    # 3. Build Native object
    $attr = [IO.FileAttributes]($isContainer ? 'Directory' : 0)
    if ($Metadata.ContainsKey('FileAttributes')) { $attr = [IO.FileAttributes]$Metadata.FileAttributes }

    $native = [PSCustomObject]@{
        Platform = $IsWindows ? 'Windows' : 'Unix'
        FileAttributes = $attr
    }
    if ($Metadata.Native) { $native = $Metadata.Native }

    # 4. Construct TreeItem
    $splat = @{
        FullPath    = $fullPath; Name = $Name; Kind = $kind; IsContainer = $isContainer
        Children    = @($Metadata.Children -or @()); Link = $link; Native = $native
        Depth       = $Depth; ParentPath = $ParentPath
    }

    foreach ($prop in @('IsHidden', 'IsReadOnly', 'CreationTime', 'LastWriteTime')) {
        if ($Metadata.ContainsKey($prop)) { $splat[$prop] = $Metadata[$prop] }
    }

    New-TreeItem @splat
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

    if ([string]::IsNullOrWhiteSpace($ParentPath)) {
        $ParentPath = $IsWindows ? 'C:\' : '/'
    }
    $rootName   = 'Root'

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
                $kind  = ($kind -eq 'Unknown') ? 'Directory' : $kind

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
                if ($Descriptor.ContainsKey($key) -and $Descriptor[$key]) {
                    $splat[$key] = $Descriptor[$key]
                }
            }

            return $splat
        }

        $descriptor = @{}

        # Fill descriptor with only the values you discovered
        if ($kind -ne 'Unknown')     { $descriptor.Kind = $kind }
        if ($isDir)                  { $descriptor.IsContainer = $true }
        if ($isHidden)               { $descriptor.IsHidden = $isHidden }
        if ($isExec)                 { $descriptor.IsExecutable = $isExec }
        if ($isRO)                   { $descriptor.IsReadOnly = $isRO }
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

    # We treat the input structure as the contents of a single directory named 'Root'.
    return BuildFixtureNode $rootName $Structure $parentPath 0
}

function Copy-FixtureTreeItemForProvider {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object] $Item,

        [Parameter(Mandatory)]
        [string] $ParentPath,

        [int] $Depth = 0
    )

    $states = @()
    if ($Item.PSObject.Properties.Match('States') -and $null -ne $Item.States) {
        $states = @($Item.States)
    }

    $splat = @{
        FullPath    = $Item.FullPath
        Name        = $Item.Name
        Kind        = $Item.Kind
        IsContainer = $Item.IsContainer
        ParentPath  = $ParentPath
        Depth       = $Depth
        Children    = @($Item.Children)
        States      = $states
    }

    foreach ($propertyName in @(
        'Length'
        'CreationTime'
        'LastWriteTime'
        'LastAccessTime'
        'Link'
        'Permissions'
        'Native'
    )) {
        if ($Item.PSObject.Properties.Match($propertyName) -and $Item.$propertyName) {
            $splat[$propertyName] = $Item.$propertyName
        }
    }

    New-TreeItem @splat
}

function Find-FixtureTreeItemByPath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object] $Root,

        [Parameter(Mandatory)]
        [string] $Path
    )

    if ($Root.FullPath -eq $Path) {
        return $Root
    }

    foreach ($child in @($Root.Children)) {
        if ($child.FullPath -eq $Path) {
            return $child
        }

        if ($child.IsContainer -and $child.Children) {
            $found = Find-FixtureTreeItemByPath `
                -Root $child `
                -Path $Path

            if ($null -ne $found) {
                return $found
            }
        }
    }

    return $null
}

function Convert-FixtureTreeToProviderResult {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object] $Root,

        [Parameter(Mandatory)]
        [string] $Path,

        [int] $Depth = 0
    )

    $node = Find-FixtureTreeItemByPath -Root $Root -Path $Path

    if ($null -eq $node) {
        return [PSCustomObject]@{
            Files       = @()
            Directories = @()
        }
    }

    $files = @()
    $directories = @()

    foreach ($child in @($node.Children)) {
        $providerChild = Copy-FixtureTreeItemForProvider `
            -Item $child `
            -ParentPath $Path `
            -Depth $Depth

        if ($providerChild.IsContainer) {
            $directories += $providerChild
        }
        else {
            $files += $providerChild
        }
    }

    [PSCustomObject]@{
        Files       = $files
        Directories = $directories
    }
}

function New-FixtureTreeChildProvider {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object] $Root,

        [string] $Name = 'Fixture'
    )

    $capturedRoot = $Root

    [PSCustomObject]@{
        PSTypeName   = 'ShowTree.TreeChildProvider'
        Name         = $Name
        ProviderMode = 'Fixture'
        RootPath     = $capturedRoot.FullPath
        GetChildren  = {
            param(
                [Parameter(Mandatory)]
                [string] $Path,

                [int] $Depth = 0
            )

            function Find-CapturedFixtureNodeByPath {
                param(
                    [Parameter(Mandatory)]
                    [object] $Node,

                    [Parameter(Mandatory)]
                    [string] $TargetPath
                )

                if ($Node.FullPath -eq $TargetPath) {
                    return $Node
                }

                foreach ($child in @($Node.Children)) {
                    if ($child.FullPath -eq $TargetPath) {
                        return $child
                    }

                    if ($child.IsContainer -and $child.Children) {
                        $found = Find-CapturedFixtureNodeByPath `
                            -Node $child `
                            -TargetPath $TargetPath

                        if ($found) {
                            return $found
                        }
                    }
                }

                return $null
            }

            function Copy-CapturedFixtureNodeForProvider {
                param(
                    [Parameter(Mandatory)]
                    [object] $Item,

                    [Parameter(Mandatory)]
                    [string] $ParentPath,

                    [int] $Depth = 0
                )

                $states = @()
                if ($Item.PSObject.Properties.Match('States') -and $null -ne $Item.States) {
                    $states = @($Item.States)
                }

                $splat = @{
                    FullPath    = $Item.FullPath
                    Name        = $Item.Name
                    Kind        = $Item.Kind
                    IsContainer = $Item.IsContainer
                    ParentPath  = $ParentPath
                    Depth       = $Depth
                    Children    = @($Item.Children)
                    States      = $states
                }

                foreach ($propertyName in @(
                    'Length'
                    'CreationTime'
                    'LastWriteTime'
                    'LastAccessTime'
                    'Link'
                    'Permissions'
                    'Native'
                )) {
                    if ($Item.PSObject.Properties.Match($propertyName) -and $Item.$propertyName) {
                        $splat[$propertyName] = $Item.$propertyName
                    }
                }

                New-TreeItem @splat
            }

            $node = Find-CapturedFixtureNodeByPath `
                -Node $capturedRoot `
                -TargetPath $Path

            if ($null -eq $node) {
                return [PSCustomObject]@{
                    Files       = @()
                    Directories = @()
                }
            }

            $files = @()
            $directories = @()

            foreach ($child in @($node.Children)) {
                $providerChild = Copy-CapturedFixtureNodeForProvider `
                    -Item $child `
                    -ParentPath $Path `
                    -Depth $Depth

                if ($providerChild.IsContainer) {
                    $directories += $providerChild
                }
                else {
                    $files += $providerChild
                }
            }

            [PSCustomObject]@{
                Files       = $files
                Directories = $directories
            }
        }.GetNewClosure()
    }
}

function New-FixtureTreeRecord {
    [CmdletBinding()]
    param(
        [ValidateSet('Item', 'Gap')]
        [string] $RecordType = 'Item',

        [string] $Name,
        [string] $ParentPath,
        [int] $Depth = 0,
        [int] $RelativeDepth = $null,
        [bool] $IsLastSibling = $false,
        [bool[]] $AncestorIsLastSibling = @(),
        [bool] $HasLaterSiblingDirectory = $false,
        [hashtable] $Metadata = @{}
    )

    if ($null -eq $RelativeDepth) { $RelativeDepth = $Depth }

    $layout = New-TreeLayout `
            -Depth $Depth -RelativeDepth $RelativeDepth `
            -IsLastSibling:$IsLastSibling -AncestorIsLastSibling $AncestorIsLastSibling `
            -HasLaterSiblingDirectory:$HasLaterSiblingDirectory

    if ($RecordType -eq 'Gap') {
        return New-TreeRecord -RecordType Gap -TreeLayout $layout
    }

    $item = New-FixtureTreeItem -Name $Name -ParentPath $ParentPath -Depth $Depth -Metadata $Metadata
    New-TreeRecord -RecordType Item -TreeItem $item -TreeLayout $layout
}

function New-FixtureTreeRecordStream {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Collections.IDictionary] $Structure,
        [string] $ParentPath,
        [int] $Depth = 0,
        [bool[]] $AncestorIsLastSibling = @()
    )

    if (-not $ParentPath) {
        $ParentPath = $IsWindows ? 'C:\' : '/'
        $ParentPath = Join-Path $ParentPath 'Root'
    }

    $itemKeys = @(foreach ($key in $Structure.Keys) { if ([string]$key -notlike '<gap*') { $key } })

    foreach ($key in $Structure.Keys) {
        $keyText = [string]$key
        $value = $Structure[$key]

        if ($keyText -like '<gap*') {
            New-TreeRecord -RecordType Gap -TreeLayout (New-TreeLayout -Depth $Depth -RelativeDepth $Depth -AncestorIsLastSibling $AncestorIsLastSibling)
            continue
        }

        $itemIndex = [Array]::IndexOf($itemKeys, $key)
        $isLastSibling = $itemIndex -eq ($itemKeys.Count - 1)

        # 1. Distinguish between a child map and a metadata descriptor
        # A descriptor is a dictionary containing reserved keys like 'Children' or 'Target'
        $reservedKeys = @('Children', 'Target', 'IsSymlink', 'IsJunction', 'IsContainer', 'IsDirectory', 'Kind', 'Native', 'IsHidden', 'FileAttributes')
        $isDescriptor = $value -is [hashtable] -and 
                        (($value.Keys | Where-Object { $_ -in $reservedKeys }) -or 
                            ($value -isnot [System.Collections.Specialized.OrderedDictionary]))
        
        $metadata = @{}
        $children = $null

        if ($isDescriptor) {
            $metadata = $value.Clone()
            if ($value.ContainsKey('Children')) { $children = $value.Children }
        } else {
            $children = $value
        }

        # 2. Determine container status
        $isDirectory = ($children -is [System.Collections.IDictionary]) -or 
                        ($metadata.IsContainer -eq $true) -or 
                        ($metadata.IsDirectory -eq $true)
        
        if ($isDirectory) { $metadata.IsContainer = $true }

        # 3. Determine if there's a later sibling directory (for Normal mode gaps)
        $hasLaterSiblingDirectory = $false
        for ($i = $itemIndex + 1; $i -lt $itemKeys.Count; $i++) {
            $laterVal = $Structure[$itemKeys[$i]]
            $isLaterContainer = ($laterVal -is [System.Collections.Specialized.OrderedDictionary]) -or 
                                ($laterVal -is [hashtable] -and ($laterVal.IsContainer -or $laterVal.IsDirectory -or $laterVal.ContainsKey('Children')))
            if ($isLaterContainer) {
                $hasLaterSiblingDirectory = $true; break
            }
        }
    
        # 4. Emit the Item Record
        New-FixtureTreeRecord -Name $keyText -ParentPath $ParentPath -Depth $Depth `
            -IsLastSibling:$isLastSibling -AncestorIsLastSibling $AncestorIsLastSibling `
            -HasLaterSiblingDirectory:$hasLaterSiblingDirectory -Metadata $metadata

        # 5. Recurse only if it's a container and has children
        if ($isDirectory -and ($children -is [System.Collections.IDictionary])) {
            New-FixtureTreeRecordStream -Structure $children -ParentPath (Join-Path $ParentPath $keyText) `
                -Depth ($Depth + 1) -AncestorIsLastSibling (@($AncestorIsLastSibling) + $isLastSibling)
        }
    }
}

function Convert-TreeRecordToFixtureStructure {
    [CmdletBinding()]
    param([Parameter(Mandatory, ValueFromPipeline)] [object] $Record)

    begin {
        function Format-FixtureCode($Data, $Indent = 0) {
            $pad = "    " * $Indent; $innerPad = "    " * ($Indent + 1)
            if ($null -eq $Data) { return '$null' }
            if ($Data -is [string]) { return "'$Data'" }
            if ($Data -is [bool]) { return ('$false', '$true')[$Data] }
            if ($Data -is [System.Collections.Specialized.OrderedDictionary]) {
                if ($Data.Count -eq 0) { return "[ordered]@{ }" }
                $lines = @("[ordered]@{")
                foreach ($key in $Data.Keys) { $lines += "$innerPad'$key' = $(Format-FixtureCode $Data[$key] ($Indent + 1))" }
                return ($lines + "$pad}") -join "`n"
            }
            if ($Data -is [hashtable]) {
                # Metadata blobs stay as standard hashtables to differentiate them from tree levels
                $parts = foreach ($k in $Data.Keys) { "'$k' = $(Format-FixtureCode $Data[$k] ($Indent + 1))" }
                return "@{" + ($parts -join "; ") + "}"
            }
            return "$Data"
        }
        $script:CapturedRoot = [ordered]@{ }; $script:DictStack = [System.Collections.Generic.List[object]]::new(); $script:DictStack.Add($script:CapturedRoot); $script:Counter = 0
    }

    process {
        $depth = $Record.TreeLayout.Depth
        while ($script:DictStack.Count -gt ($depth + 1)) { $script:DictStack.RemoveAt($script:DictStack.Count - 1) }
        while ($script:DictStack.Count -le $depth) {
            $m = [ordered]@{ }; $script:DictStack[$script:DictStack.Count-1]["<auto-$($script:DictStack.Count)>"] = $m; $script:DictStack.Add($m)
        }

        $target = $script:DictStack[$depth]

        if ($Record.RecordType -eq 'Gap') {
            $target["<gap-$($script:Counter)>"] = $null
        } else {
            $item = $Record.TreeItem
            if ($item.IsContainer) {
                $kids = [ordered]@{ }
                $isSpecial = $item.Kind -in @('Symlink', 'Junction') -or $item.IsHidden
                if ($isSpecial) {
                    # Standard hashtable for descriptor
                    $desc = @{ IsContainer = $true; Children = $kids }
                    if ($item.Kind -in @('Symlink', 'Junction')) { $desc.IsSymlink = $true; $desc.Target = $item.Link.Target }
                    if ($item.IsHidden) { $desc.IsHidden = $true }
                    $target[$item.Name] = $desc
                } else { $target[$item.Name] = $kids }
                $script:DictStack.Add($kids)
            } else {
                $isSystem = ($item.Native.FileAttributes) -and ($item.Native.FileAttributes -band [IO.FileAttributes]::System)
                if ($item.IsHidden -or $item.Kind -eq 'Symlink' -or $isSystem) {
                    $desc = @{ }
                    if ($item.IsHidden) { $desc.IsHidden = $true }
                    if ($item.Kind -eq 'Symlink') { $desc.IsSymlink = $true; $desc.Target = $item.Link.Target }
                    if ($isSystem) { $desc.FileAttributes = 'System' }
                    $target[$item.Name] = $desc
                } else { $target[$item.Name] = $null }
            }
        }
        $script:Counter++
    }

    end {
        $code = Format-FixtureCode -Data $script:CapturedRoot
        Remove-Variable CapturedRoot, DictStack, Counter -Scope script
        return $code
    }
}
