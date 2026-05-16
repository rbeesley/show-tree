# src\Tests\Unit\Filtering\Filtering.Tests.ps1

BeforeAll {
    $script:ModuleUnderTest = . "$PSScriptRoot\..\..\Helpers\Import-ModuleUnderTest.ps1" `
        -StartPath $PSScriptRoot `
        -ModuleName 'ShowTree' `
        -SourceRootName 'src' `
        -Exclude 'src/Tests/*' `
        -PassThru
}

Describe "Get-FilteredTreeItems" {
    It "Excludes exact matches" {
        InModuleScope ShowTree {
            . "$PSScriptRoot\..\..\Helpers\PrivateHelpers.ps1"

            $items = @(
                New-TestItem -Name ".git"
                New-TestItem -Name ".github"
            )

            $result = Get-FilteredTreeItems -Items $items -Exclude ".git"

            $result.Name | Should -Not -Contain ".git"
            $result.Name | Should -Contain ".github"
        }
    }

    It "Glob include resurrects items excluded by glob" {
        InModuleScope ShowTree {
            . "$PSScriptRoot\..\..\Helpers\PrivateHelpers.ps1"

            $items = @(
                New-TestItem -Name ".git"
                New-TestItem -Name ".github"
            )

            $result = Get-FilteredTreeItems -Items $items -Exclude ".*" -Include ".github"

            $result.Name | Should -Contain ".github"
            $result.Name | Should -Not -Contain ".git"
        }
    }

    It "Exact exclude beats glob include" {
        InModuleScope ShowTree {
            . "$PSScriptRoot\..\..\Helpers\PrivateHelpers.ps1"

            $items = @(
                New-TestItem -Name ".git"
                New-TestItem -Name ".gitignore"
            )

            $result = Get-FilteredTreeItems -Items $items -Exclude ".git" -Include ".git*"

            $result.Name | Should -Not -Contain ".git"
            $result.Name | Should -Contain ".gitignore"
        }
    }

    It "Include resurrects hidden items" {
        InModuleScope ShowTree {
            . "$PSScriptRoot\..\..\Helpers\PrivateHelpers.ps1"

            $items = @(
                New-TestItem -Name ".config" -Attributes ([IO.FileAttributes]::Hidden)
                New-TestItem -Name "visible.txt"
            )

            $result = Get-FilteredTreeItems -Items $items -HideHidden -Include ".config"

            $result.Name | Should -Contain ".config"
        }
    }

    It "Preserves original ordering" {
        InModuleScope ShowTree {
            . "$PSScriptRoot\..\..\Helpers\PrivateHelpers.ps1"

            $items = @(
                New-TestItem -Name "a"
                New-TestItem -Name "b"
                New-TestItem -Name "c"
            )

            $result = Get-FilteredTreeItems -Items $items -Exclude "b"

            $result.Name | Should -Be @("a","c")
        }
    }

    It 'correctly filters a single directory even on Windows PowerShell 5.1' {
        InModuleScope ShowTree {
            . "$PSScriptRoot\..\..\Helpers\PrivateHelpers.ps1"

            $items = @(
                New-TestItem -Name "Normal"
                New-TestItem -Name "Hidden" -Attributes ([IO.FileAttributes]::Hidden)
            )

            # In 5.1, a single object return from a function might lose .Count if not handled as array
            $filtered = @(Get-FilteredTreeItems -Items $items -HideHidden)
            
            $filtered.Count | Should -Be 1
            $filtered[0].Name | Should -Be "Normal"
            
            # Verify that Hidden was actually identified as hidden
            $items[1].IsHidden | Should -Be $true
        }
    }
}
