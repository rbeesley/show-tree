# src\Tests\Private\TreeItem.Tests.ps1

BeforeAll {
    $script:ModuleUnderTest = . "$PSScriptRoot\..\Helpers\Import-ModuleUnderTest.ps1" `
        -StartPath $PSScriptRoot `
        -ModuleName 'ShowTree' `
        -SourceRootName 'src' `
        -Exclude 'src/Tests/*' `
        -PassThru
}

Describe "New-TreeItem" {
    It "creates a basic file TreeItem with correct defaults" {
        InModuleScope ShowTree { 
            . "$PSScriptRoot\..\Helpers\PrivateHelpers.ps1"

            $item = New-TreeItem -FullPath 'C:\Test\File.txt' -IsDirectory:$false

            $item.PSObject.TypeNames[0] | Should -Be 'ShowTree.TreeItem'
            $item.Name        | Should -Be 'File.txt'
            $item.FullPath    | Should -Be 'C:\Test\File.txt'
            $item.Type        | Should -Be 'File'
            $item.IsDirectory | Should -Be $false
            $item.IsSymlink   | Should -Be $false
            $item.IsJunction  | Should -Be $false
            $item.Attributes  | Should -Be @()
            $item.Children    | Should -Be @()
        }
    }

    It "creates a directory TreeItem with correct defaults" {
        InModuleScope ShowTree { 
            . "$PSScriptRoot\..\Helpers\PrivateHelpers.ps1"

            $item = New-TreeItem -FullPath 'C:\Test\Dir' -IsDirectory:$true

            $item.Name        | Should -Be 'Dir'
            $item.Type        | Should -Be 'Directory'
            $item.IsDirectory | Should -Be $true
        }
    }

    It "allows overriding Name and Type" {
        InModuleScope ShowTree { 
            . "$PSScriptRoot\..\Helpers\PrivateHelpers.ps1"

            $item = New-TreeItem `
                -FullPath 'C:\X\Y' `
                -IsDirectory:$true `
                -Name 'CustomName' `
                -Type 'CustomType'

            $item.Name | Should -Be 'CustomName'
            $item.Type | Should -Be 'CustomType'
        }
    }

    It "supports attributes" {
        InModuleScope ShowTree { 
            . "$PSScriptRoot\..\Helpers\PrivateHelpers.ps1"

            $item = New-TreeItem `
                -FullPath 'C:\Hidden\File.txt' `
                -IsDirectory:$false `
                -Attributes @('Hidden','System')

            $item.Attributes | Should -Contain 'Hidden'
            $item.Attributes | Should -Contain 'System'
        }
    }

    It "supports children" {
        InModuleScope ShowTree { 
            . "$PSScriptRoot\..\Helpers\PrivateHelpers.ps1"

            $child = New-TreeItem -FullPath 'C:\Test\Child.txt' -IsDirectory:$false
            $parent = New-TreeItem -FullPath 'C:\Test' -IsDirectory:$true -Children @($child)

            $parent.Children.Count | Should -Be 1
            $parent.Children[0].Name | Should -Be 'Child.txt'
        }
    }

    It "supports symlink and junction flags" {
        InModuleScope ShowTree { 
            . "$PSScriptRoot\..\Helpers\PrivateHelpers.ps1"

            $item = New-TreeItem `
                -FullPath 'C:\Link' `
                -IsDirectory:$true `
                -IsSymlink:$true `
                -IsJunction:$false

            $item.IsSymlink  | Should -Be $true
            $item.IsJunction | Should -Be $false
        }
    }
}
