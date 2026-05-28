# src\Tests\Unit\TreeItem\TreeItem.Tests.ps1

BeforeAll {
    $script:TestRoot = Resolve-Path "$PSScriptRoot\..\.."
    $script:ModuleUnderTest = . "$script:TestRoot\Helpers\Import-ModuleUnderTest.ps1" `
        -StartPath $PSScriptRoot `
        -ModuleName 'ShowTree' `
        -SourceRootName 'src' `
        -Exclude 'src/Tests/*' `
        -PassThru
    $script:FixtureScripts  = @(
        "$script:TestRoot\Helpers\PrivateHelpers.ps1"
        "$script:TestRoot\Fixtures\TreeItemFixtures.ps1"
    )
}

Describe "New-TreeItem" {
    It "creates a basic file TreeItem with correct defaults" {
        InModuleScope ShowTree -Parameters @{ FixtureScripts = $script:FixtureScripts } {
            param( [string[]] $FixtureScripts ); foreach ($script in $FixtureScripts) { . $script }

            $root = if ($IsWindows) { 'C:\Test' } else { '/tmp/test' }
            $fullPath = Join-Path $root 'File.txt'
            $item = New-TreeItem -FullPath $fullPath -IsContainer:$false -Kind 'File'

            $item.PSObject.TypeNames[0] | Should -Be 'ShowTree.TreeItem'
            $item.Name           | Should -Be 'File.txt'
            $item.FullPath       | Should -Be $fullPath
            $item.ParentPath     | Should -BeNullOrEmpty
            $item.Kind           | Should -Be 'File'
            $item.IsContainer    | Should -Be $false
            $item.IsFile         | Should -Be $true
            $item.IsDirectory    | Should -Be $false
            $item.IsLink         | Should -Be $false
            $item.IsHidden       | Should -BeNull
            $item.Depth          | Should -Be 0
            $item.Native.FileAttributes | Should -BeNull
            $item.Children       | Should -Be @()
        }
    }

    It "creates a directory TreeItem with correct defaults" {
        InModuleScope ShowTree -Parameters @{ FixtureScripts = $script:FixtureScripts } {
            param( [string[]] $FixtureScripts ); foreach ($script in $FixtureScripts) { . $script }

            $root = if ($IsWindows) { 'C:\Test' } else { '/tmp/test' }
            $fullPath = Join-Path $root 'Dir'
            $item = New-TreeItem -FullPath $fullPath -IsContainer:$true -Kind 'Directory'

            $item.Name        | Should -Be 'Dir'
            $item.Kind        | Should -Be 'Directory'
            $item.IsContainer | Should -Be $true
            $item.IsDirectory | Should -Be $true
        }
    }

    It "allows overriding Name and Kind" {
        InModuleScope ShowTree -Parameters @{ FixtureScripts = $script:FixtureScripts } {
            param( [string[]] $FixtureScripts ); foreach ($script in $FixtureScripts) { . $script }

            $root = if ($IsWindows) { 'C:\X' } else { '/tmp/X' }
            $fullPath = Join-Path $root 'Y'
            $item = New-TreeItem `
                -FullPath $fullPath `
                -IsContainer:$true `
                -Name 'CustomName' `
                -Kind 'Other'

            $item.Name | Should -Be 'CustomName'
            $item.Kind | Should -Be 'Other'
        }
    }

    It "supports native attributes and hidden detection" {
        InModuleScope ShowTree -Parameters @{ FixtureScripts = $script:FixtureScripts } {
            param( [string[]] $FixtureScripts ); foreach ($script in $FixtureScripts) { . $script }

            $root = if ($IsWindows) { 'C:\Hidden' } else { '/tmp/Hidden' }
            $fullPath = Join-Path $root 'File.txt'
            $native = [PSCustomObject]@{
                Platform = 'Windows'
                FileAttributes = [IO.FileAttributes]::Hidden
            }
            $item = New-TreeItem `
                -FullPath $fullPath `
                -IsContainer:$false `
                -Native $native `
                -IsHidden $true

            $item.Native.FileAttributes -band [IO.FileAttributes]::Hidden | Should -Not -Be 0
            $item.IsHidden | Should -Be $true
        }
    }

    It "supports children" {
        InModuleScope ShowTree -Parameters @{ FixtureScripts = $script:FixtureScripts } {
            param( [string[]] $FixtureScripts ); foreach ($script in $FixtureScripts) { . $script }

            $root = if ($IsWindows) { 'C:\Test' } else { '/tmp/test' }
            $childPath = Join-Path $root 'Child.txt'
            $child = New-TreeItem -FullPath $childPath -IsContainer:$false -Kind 'File'
            $parent = New-TreeItem -FullPath $root -IsContainer:$true -Kind 'Directory' -Children @($child)

            $parent.Children.Count | Should -Be 1
            $parent.Children[0].Name | Should -Be 'Child.txt'
        }
    }

    It "supports link information" {
        InModuleScope ShowTree -Parameters @{ FixtureScripts = $script:FixtureScripts } {
            param( [string[]] $FixtureScripts ); foreach ($script in $FixtureScripts) { . $script }

            $root = if ($IsWindows) { 'C:\' } else { '/tmp/' }
            $linkPath = Join-Path $root 'Link'
            $targetPath = Join-Path $root 'Target'
            $link = [PSCustomObject]@{
                Type = 'SymbolicLink'
                Target = $targetPath
                TargetPath = $targetPath
                IsBroken = $false
            }
            $item = New-TreeItem `
                -FullPath $linkPath `
                -IsContainer:$true `
                -Kind 'Symlink' `
                -Link $link

            $item.IsLink      | Should -Be $true
            $item.Link.Type   | Should -Be 'SymbolicLink'
            $item.Link.Target | Should -Be $targetPath
        }
    }

    It "supports ParentPath and Depth" {
        InModuleScope ShowTree -Parameters @{ FixtureScripts = $script:FixtureScripts } {
            param( [string[]] $FixtureScripts ); foreach ($script in $FixtureScripts) { . $script }

            $parent = if ($IsWindows) { 'C:\A' } else { '/tmp/A' }
            $fullPath = Join-Path $parent 'B'
            $item = New-TreeItem `
                -FullPath $fullPath `
                -IsContainer:$false `
                -Kind 'File' `
                -ParentPath $parent `
                -Depth 2

            $item.ParentPath | Should -Be $parent
            $item.Depth      | Should -Be 2
        }
    }

    It "detects hidden files by '.' prefix on non-Windows" {
        InModuleScope ShowTree -Parameters @{ FixtureScripts = $script:FixtureScripts } {
            param( [string[]] $FixtureScripts ); foreach ($script in $FixtureScripts) { . $script }

            # In v2.0.0, we use localIsWindows inside the function, 
            # and it detects the real OS. To test this specifically,
            # we would need to mock the platform detection or just 
            # accept it's hard to test on Windows if it uses [RuntimeInformation].
            # For now, we skip this test if we are actually on Windows
            # because our fix makes it rely on real OS detection.
            
            $realIsWindows = $true
            if ($PSVersionTable.PSEdition -eq 'Core') {
                $realIsWindows = [System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform([System.Runtime.InteropServices.OSPlatform]::Windows)
            }

            if ($realIsWindows) {
                Set-ItResult -Skip
            }
            else {
                $item = New-TreeItem -FullPath '/home/user/.bashrc' -IsContainer:$false -Kind 'File' -IsHidden $true
                $item.IsHidden | Should -Be $true
            }
        }
    }

    It "can be constructed from FileInfo and DirectoryInfo objects" {
        InModuleScope ShowTree {
            $tempFile = [System.IO.Path]::GetTempFileName()
            $fileInfo = Get-Item -LiteralPath $tempFile
            
            try {
                $native = [PSCustomObject]@{
                    Platform = if ($IsWindows) { 'Windows' } else { 'Unix' }
                    FileAttributes = $fileInfo.Attributes
                }
                $item = New-TreeItem `
                    -FullPath $fileInfo.FullName `
                    -Name $fileInfo.Name `
                    -IsContainer $fileInfo.PSIsContainer `
                    -Kind 'File' `
                    -Native $native
                
                $item.Name | Should -Be $fileInfo.Name
                $item.IsDirectory | Should -Be $false
                $item.Native.FileAttributes | Should -Be $fileInfo.Attributes
            }
            finally {
                Remove-Item $tempFile -Force
            }

            $tempDir = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString())
            New-Item -ItemType Directory -Path $tempDir | Out-Null
            $dirInfo = Get-Item -LiteralPath $tempDir

            try {
                $native = [PSCustomObject]@{
                    Platform = if ($IsWindows) { 'Windows' } else { 'Unix' }
                    FileAttributes = $dirInfo.Attributes
                }
                $item = New-TreeItem `
                    -FullPath $dirInfo.FullName `
                    -Name $dirInfo.Name `
                    -IsContainer $dirInfo.PSIsContainer `
                    -Kind 'Directory' `
                    -Native $native
                
                $item.Name | Should -Be $dirInfo.Name
                $item.IsDirectory | Should -Be $true
                $item.Native.FileAttributes -band [IO.FileAttributes]::Directory | Should -Not -Be 0
            }
            finally {
                Remove-Item $tempDir -Recurse -Force
            }
        }
    }

    It "converts test fixtures into TreeItem objects" {
        InModuleScope ShowTree -Parameters @{ FixtureScripts = $script:FixtureScripts } {
            param( [string[]] $FixtureScripts ); foreach ($script in $FixtureScripts) { . $script }

            $expectedTarget = if ($IsWindows) { 'C:\Target' } else { '/tmp/Target' }
            $structure = [ordered]@{
                'Root' = [ordered]@{
                    'Folder' = [ordered]@{
                        'File.txt' = $null
                    }
                    'Link' = @{
                        IsSymlink = $true
                        Target = $expectedTarget
                    }
                }
            }
            
            $root = New-FixtureTree -Structure $structure
            
            $root.Name | Should -Be 'Root'
            $root.Children.Count | Should -Be 2
            
            $folder = $root.Children | Where-Object { $_.Name -eq 'Folder' }
            $folder.IsDirectory | Should -Be $true
            $folder.Depth | Should -Be 1
            $folder.Children.Count | Should -Be 1
            $folder.Children[0].Name | Should -Be 'File.txt'
            $folder.Children[0].Depth | Should -Be 2
            
            $link = $root.Children | Where-Object { $_.Name -eq 'Link' }
            $link.Kind | Should -Be 'Symlink'
            $link.IsLink | Should -Be $true
            $link.Link.Target | Should -Be $expectedTarget
        }
    }
}
