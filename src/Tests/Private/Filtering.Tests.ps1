# src\Tests\Private\Get-FilteredTreeItems.Tests.ps1

BeforeAll {
    $script:ModuleUnderTest = . "$PSScriptRoot\..\Helpers\Import-ModuleUnderTest.ps1" `
        -StartPath $PSScriptRoot `
        -ModuleName 'ShowTree' `
        -SourceRootName 'src' `
        -Exclude 'src/Tests/*' `
        -PassThru
}

Describe "Get-FilteredTreeItems" {
    It "Excludes exact matches" {
        InModuleScope ShowTree {
            . "$PSScriptRoot\..\Helpers\PrivateHelpers.ps1"

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
            . "$PSScriptRoot\..\Helpers\PrivateHelpers.ps1"

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
            . "$PSScriptRoot\..\Helpers\PrivateHelpers.ps1"

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
            . "$PSScriptRoot\..\Helpers\PrivateHelpers.ps1"

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
            . "$PSScriptRoot\..\Helpers\PrivateHelpers.ps1"

            $items = @(
                New-TestItem -Name "a"
                New-TestItem -Name "b"
                New-TestItem -Name "c"
            )

            $result = Get-FilteredTreeItems -Items $items -Exclude "b"

            $result.Name | Should -Be @("a","c")
        }
    }
}
