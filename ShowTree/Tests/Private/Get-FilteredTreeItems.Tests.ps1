# ShowTree\Tests\Private\Get-FilteredTreeItems.Tests.ps1

InModuleScope ShowTree {

    BeforeAll {
        . "$PSScriptRoot/PrivateHelpers.ps1"
    }

    Describe "Get-FilteredTreeItems" {

        It "Excludes exact matches" {
            $items = @(
                New-TestItem -Name ".git"
                New-TestItem -Name ".github"
            )

            $result = Get-FilteredTreeItems -Items $items -Exclude ".git"

            $result.Name | Should -Not -Contain ".git"
            $result.Name | Should -Contain ".github"
        }

        It "Glob include resurrects items excluded by glob" {
            $items = @(
                New-TestItem -Name ".git"
                New-TestItem -Name ".github"
            )

            $result = Get-FilteredTreeItems -Items $items -Exclude ".*" -Include ".github"

            $result.Name | Should -Contain ".github"
            $result.Name | Should -Not -Contain ".git"
        }

        It "Exact exclude beats glob include" {
            $items = @(
                New-TestItem -Name ".git"
                New-TestItem -Name ".gitignore"
            )

            $result = Get-FilteredTreeItems -Items $items -Exclude ".git" -Include ".git*"

            $result.Name | Should -Not -Contain ".git"
            $result.Name | Should -Contain ".gitignore"
        }

        It "Include resurrects hidden items" {
            $items = @(
                New-TestItem -Name ".config" -Attributes ([IO.FileAttributes]::Hidden)
            )

            $result = Get-FilteredTreeItems -Items $items -HideHidden -Include ".config"

            $result.Name | Should -Contain ".config"
        }

        It "Preserves original ordering" {
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