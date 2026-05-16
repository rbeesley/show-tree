# src\Tests\Unit\TreeItem\TreeItem.Tests.ps1

BeforeAll {
    $script:ModuleUnderTest = . "$PSScriptRoot\..\..\Helpers\Import-ModuleUnderTest.ps1" `
        -StartPath $PSScriptRoot `
        -ModuleName 'ShowTree' `
        -SourceRootName 'src' `
        -Exclude 'src/Tests/*' `
        -PassThru
}

Describe "New-TreeItem" {
    It "creates a basic file TreeItem with correct defaults" {
        InModuleScope ShowTree {
            . "$PSScriptRoot\..\..\Helpers\PrivateHelpers.ps1"

            $root = if ($IsWindows) { 'C:\Test' } else { '/tmp/test' }
            $fullPath = Join-Path $root 'File.txt'
            $item = New-TreeItem -FullPath $fullPath -IsDirectory:$false

            $item.PSObject.TypeNames[0] | Should -Be 'ShowTree.TreeItem'
            $item.Name           | Should -Be 'File.txt'
            $item.FullPath       | Should -Be $fullPath
            $item.Parent         | Should -BeNullOrEmpty
            $item.Type           | Should -Be 'File'
            $item.IsDirectory    | Should -Be $false
            $item.IsSymlink      | Should -Be $false
            $item.IsJunction     | Should -Be $false
            $item.IsReparsePoint | Should -Be $false
            $item.IsHidden       | Should -Be $false
            $item.IsSystem       | Should -Be $false
            $item.Depth          | Should -Be 0
            $item.Attributes     | Should -Be 0
            $item.Children       | Should -Be @()
        }
    }

    It "creates a directory TreeItem with correct defaults" {
        InModuleScope ShowTree {
            . "$PSScriptRoot\..\..\Helpers\PrivateHelpers.ps1"

            $root = if ($IsWindows) { 'C:\Test' } else { '/tmp/test' }
            $fullPath = Join-Path $root 'Dir'
            $item = New-TreeItem -FullPath $fullPath -IsDirectory:$true

            $item.Name        | Should -Be 'Dir'
            $item.Type        | Should -Be 'Directory'
            $item.IsDirectory | Should -Be $true
        }
    }

    It "allows overriding Name and Type" {
        InModuleScope ShowTree {
            . "$PSScriptRoot\..\..\Helpers\PrivateHelpers.ps1"

            $root = if ($IsWindows) { 'C:\X' } else { '/tmp/X' }
            $fullPath = Join-Path $root 'Y'
            $item = New-TreeItem `
                -FullPath $fullPath `
                -IsDirectory:$true `
                -Name 'CustomName' `
                -Type 'CustomType'

            $item.Name | Should -Be 'CustomName'
            $item.Type | Should -Be 'CustomType'
        }
    }

    It "supports attributes and hidden/system detection" {
        InModuleScope ShowTree {
            . "$PSScriptRoot\..\..\Helpers\PrivateHelpers.ps1"

            $root = if ($IsWindows) { 'C:\Hidden' } else { '/tmp/Hidden' }
            $fullPath = Join-Path $root 'File.txt'
            $item = New-TreeItem `
                -FullPath $fullPath `
                -IsDirectory:$false `
                -Attributes ([IO.FileAttributes]::Hidden -bor [IO.FileAttributes]::System)

            $item.Attributes -band [IO.FileAttributes]::Hidden | Should -Not -Be 0
            $item.Attributes -band [IO.FileAttributes]::System | Should -Not -Be 0
            $item.IsHidden | Should -Be $true
            $item.IsSystem | Should -Be $true
        }
    }

    It "supports children" {
        InModuleScope ShowTree {
            . "$PSScriptRoot\..\..\Helpers\PrivateHelpers.ps1"

            $root = if ($IsWindows) { 'C:\Test' } else { '/tmp/test' }
            $childPath = Join-Path $root 'Child.txt'
            $child = New-TreeItem -FullPath $childPath -IsDirectory:$false
            $parent = New-TreeItem -FullPath $root -IsDirectory:$true -Children @($child)

            $parent.Children.Count | Should -Be 1
            $parent.Children[0].Name | Should -Be 'Child.txt'
        }
    }

    It "supports symlink and junction flags and sets IsReparsePoint" {
        InModuleScope ShowTree {
            . "$PSScriptRoot\..\..\Helpers\PrivateHelpers.ps1"

            $root = if ($IsWindows) { 'C:\' } else { '/tmp/' }
            $linkPath = Join-Path $root 'Link'
            $targetPath = Join-Path $root 'Target'
            $item = New-TreeItem `
                -FullPath $linkPath `
                -IsDirectory:$true `
                -IsSymlink:$true `
                -IsJunction:$false `
                -Target $targetPath

            $item.IsSymlink      | Should -Be $true
            $item.IsJunction     | Should -Be $false
            $item.IsReparsePoint | Should -Be $true
            $item.Target         | Should -Be $targetPath
        }
    }

    It "supports Parent and Depth" {
        InModuleScope ShowTree {
            . "$PSScriptRoot\..\..\Helpers\PrivateHelpers.ps1"

            $parent = if ($IsWindows) { 'C:\A' } else { '/tmp/A' }
            $fullPath = Join-Path $parent 'B'
            $item = New-TreeItem `
                -FullPath $fullPath `
                -IsDirectory:$false `
                -Parent $parent `
                -Depth 2

            $item.Parent | Should -Be $parent
            $item.Depth  | Should -Be 2
        }
    }

    It "detects hidden files by '.' prefix on non-Windows" {
        InModuleScope ShowTree {
            . "$PSScriptRoot\..\..\Helpers\PrivateHelpers.ps1"

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
                $item = New-TreeItem -FullPath '/home/user/.bashrc' -IsDirectory:$false
                $item.IsHidden | Should -Be $true
            }
        }
    }

    It "can be constructed from FileInfo and DirectoryInfo objects" {
        InModuleScope ShowTree {
            $tempFile = [System.IO.Path]::GetTempFileName()
            $fileInfo = Get-Item -LiteralPath $tempFile
            
            try {
                $item = New-TreeItem `
                    -FullPath $fileInfo.FullName `
                    -Name $fileInfo.Name `
                    -IsDirectory $fileInfo.PSIsContainer `
                    -Attributes $fileInfo.Attributes
                
                $item.Name | Should -Be $fileInfo.Name
                $item.IsDirectory | Should -Be $false
                $item.Attributes | Should -Be $fileInfo.Attributes
            }
            finally {
                Remove-Item $tempFile -Force
            }

            $tempDir = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString())
            New-Item -ItemType Directory -Path $tempDir | Out-Null
            $dirInfo = Get-Item -LiteralPath $tempDir

            try {
                $item = New-TreeItem `
                    -FullPath $dirInfo.FullName `
                    -Name $dirInfo.Name `
                    -IsDirectory $dirInfo.PSIsContainer `
                    -Attributes $dirInfo.Attributes
                
                $item.Name | Should -Be $dirInfo.Name
                $item.IsDirectory | Should -Be $true
                $item.Attributes -band [IO.FileAttributes]::Directory | Should -Not -Be 0
            }
            finally {
                Remove-Item $tempDir -Recurse -Force
            }
        }
    }

    It "converts test fixtures into TreeItem objects" {
        InModuleScope ShowTree {
            . "$PSScriptRoot\..\..\Fixtures\TreeItemFixtures.ps1"
            
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
            $link.IsSymlink | Should -Be $true
            $link.IsReparsePoint | Should -Be $true
            $link.Target | Should -Be $expectedTarget
        }
    }
}
