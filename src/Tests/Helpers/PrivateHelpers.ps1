# src/Tests/Helpers/PrivateHelpers.ps1

function New-TestItem {
    param(
        [string]$Name,
        [string]$ParentPath,
        [IO.FileAttributes]$Attributes = [IO.FileAttributes]::Normal,
        [bool]$IsDirectory = $false,
        [array]$Children = @()
    )

    if (-not $ParentPath) {
        $ParentPath = if ($IsWindows) { 'C:\Test' } else { '/tmp/test' }
    }

    $fullPath = Join-Path $ParentPath $Name

    $kind = if ($IsDirectory) { 'Directory' } else { 'File' }
    if ($Attributes -band [IO.FileAttributes]::ReparsePoint) { $kind = 'Symlink' }

    $native = [PSCustomObject]@{
        Platform = if ($IsWindows) { 'Windows' } else { 'Unix' }
        FileAttributes = $Attributes
    }

    $treeItem = New-TreeItem `
        -FullPath $fullPath `
        -IsContainer $IsDirectory `
        -Kind $kind `
        -Name $Name `
        -Native $native `
        -Children $Children

    return $treeItem
}

function New-TestProviderItem {
    param(
        [Parameter(Mandatory)]
        [string] $Name,

        [string] $ParentPath,

        [switch] $IsDirectory,

        [IO.FileAttributes] $Attributes = [IO.FileAttributes]::Normal,

        [long] $Length = 0,

        [object] $Target = $null,

        [string] $DirectoryName,

        [string] $UnixMode
    )

    if (-not $ParentPath) {
        $ParentPath = if ($IsWindows) { 'C:\Test' } else { '/tmp/test' }
    }

    $fullPath = Join-Path $ParentPath $Name

    if ($IsDirectory -and (($Attributes -band [IO.FileAttributes]::Directory) -eq 0)) {
        $Attributes = $Attributes -bor [IO.FileAttributes]::Directory
    }

    $item = [PSCustomObject]@{
        Name           = $Name
        FullName       = $fullPath
        PSIsContainer  = $IsDirectory
        Attributes     = $Attributes
        Length         = if ($IsDirectory) { $null } else { $Length }
        CreationTime   = [datetime]'2026-01-01'
        LastWriteTime  = [datetime]'2026-01-02'
        LastAccessTime = [datetime]'2026-01-03'
    }

    if ($PSBoundParameters.ContainsKey('Target')) {
        $item | Add-Member -MemberType NoteProperty -Name Target -Value $Target
    }

    if ($PSBoundParameters.ContainsKey('DirectoryName')) {
        $item | Add-Member -MemberType NoteProperty -Name DirectoryName -Value $DirectoryName
    }

    if ($PSBoundParameters.ContainsKey('UnixMode')) {
        $item | Add-Member -MemberType NoteProperty -Name UnixMode -Value $UnixMode
    }

    return $item
}

function New-TestTreeChildProvider {
    param(
        [Parameter(Mandatory)]
        $Root,

        [string] $Name = 'Test'
    )

    $capturedRoot = $Root

    [PSCustomObject]@{
        PSTypeName   = 'ShowTree.TreeChildProvider'
        Name         = $Name
        ProviderMode = 'Test'
        GetChildren  = {
            param(
                [Parameter(Mandatory)]
                [string] $Path,

                [int] $Depth = 0
            )

            function Find-CapturedTestNodeByPath {
                param(
                    [Parameter(Mandatory)]
                    $Node,

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
                        $found = Find-CapturedTestNodeByPath `
                            -Node $child `
                            -TargetPath $TargetPath

                        if ($null -ne $found) {
                            return $found
                        }
                    }
                }

                return $null
            }

            $node = Find-CapturedTestNodeByPath `
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
                if ($child.IsContainer) {
                    $directories += $child
                }
                else {
                    $files += $child
                }
            }

            [PSCustomObject]@{
                Files       = $files
                Directories = $directories
            }
        }.GetNewClosure()
    }
}
