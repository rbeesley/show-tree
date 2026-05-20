# src\Tests\Unit\Enumeration\Select-TreeItem.Tests.ps1

Describe "Select-TreeItem" {
    Context "Basic Selection" {
        BeforeAll {
            $script:ModuleUnderTest = . "$PSScriptRoot\..\..\Helpers\Import-ModuleUnderTest.ps1" `
                -StartPath $PSScriptRoot `
                -ModuleName 'ShowTree' `
                -SourceRootName 'src' `
                -Exclude 'src/Tests/*' `
                -PassThru

            . (Join-Path $PSScriptRoot "..\..\Fixtures\TreeItemFixtures.ps1")
        }

        It "Passes through flat items" {
            InModuleScope ShowTree {
                . (Join-Path $PSScriptRoot "..\..\Fixtures\TreeItemFixtures.ps1")
                $items = @(
                    New-FixtureTreeItem -Name "File1.txt"
                    New-FixtureTreeItem -Name "File2.txt"
                )
                $selected = $items | Select-TreeItem
                $selected.Count | Should -Be 2
                $selected[0].Name | Should -Be "File1.txt"
                $selected[1].Name | Should -Be "File2.txt"
            }
        }

        It "Filters by Name" {
            InModuleScope ShowTree {
                . (Join-Path $PSScriptRoot "..\..\Fixtures\TreeItemFixtures.ps1")
                $items = @(
                    New-FixtureTreeItem -Name "File1.txt"
                    New-FixtureTreeItem -Name "File2.txt"
                )
                $selected = $items | Select-TreeItem -Name "File1.txt"
                $selected.Count | Should -Be 1
                $selected[0].Name | Should -Be "File1.txt"
            }
        }

        It "Filters by FilterScript" {
            InModuleScope ShowTree {
                . (Join-Path $PSScriptRoot "..\..\Fixtures\TreeItemFixtures.ps1")
                $items = @(
                    New-FixtureTreeItem -Name "File1.txt"
                    New-FixtureTreeItem -Name "Dir1" -IsDirectory $true
                )
                $selected = $items | Select-TreeItem -FilterScript { $_.IsContainer }
                $selected.Count | Should -Be 1
                $selected[0].Name | Should -Be "Dir1"
            }
        }
    }

    Context "Expansion" {
        BeforeAll {
            $script:ModuleUnderTest = . "$PSScriptRoot\..\..\Helpers\Import-ModuleUnderTest.ps1" `
                -StartPath $PSScriptRoot `
                -ModuleName 'ShowTree' `
                -SourceRootName 'src' `
                -Exclude 'src/Tests/*' `
                -PassThru

            . (Join-Path $PSScriptRoot "..\..\Fixtures\TreeItemFixtures.ps1")
        }

        It "Expands Children" {
            InModuleScope ShowTree {
                . (Join-Path $PSScriptRoot "..\..\Fixtures\TreeItemFixtures.ps1")
                $structure = [ordered]@{
                    "Root" = [ordered]@{
                        "DirA" = [ordered]@{
                            "FileA1.txt" = $null
                        }
                        "FileRoot.txt" = $null
                    }
                }
                $root = New-FixtureTree -Structure $structure
                $selected = $root | Select-TreeItem -Expand Children
                # Should return DirA and FileRoot.txt (direct children of Root)
                $selected.Count | Should -Be 2
                $selected[0].Name | Should -Be "DirA"
                $selected[1].Name | Should -Be "FileRoot.txt"
            }
        }

        It "Expands Descendants (Flattening)" {
            InModuleScope ShowTree {
                . (Join-Path $PSScriptRoot "..\..\Fixtures\TreeItemFixtures.ps1")
                $structure = [ordered]@{
                    "Root" = [ordered]@{
                        "DirA" = [ordered]@{
                            "FileA1.txt" = $null
                        }
                        "FileRoot.txt" = $null
                    }
                }
                $root = New-FixtureTree -Structure $structure
                $selected = $root | Select-TreeItem -Expand Descendants
                # Should return Root, DirA, FileA1.txt, FileRoot.txt
                $selected.Count | Should -Be 4
                $selected[0].Name | Should -Be "Root"
                $selected[1].Name | Should -Be "DirA"
                $selected[2].Name | Should -Be "FileA1.txt"
                $selected[3].Name | Should -Be "FileRoot.txt"
            }
        }

        It "Uses -Flatten as an alias for -Expand Descendants" {
            InModuleScope ShowTree {
                . (Join-Path $PSScriptRoot "..\..\Fixtures\TreeItemFixtures.ps1")
                $structure = [ordered]@{
                    "Root" = [ordered]@{
                        "DirA" = [ordered]@{
                            "FileA1.txt" = $null
                        }
                        "FileRoot.txt" = $null
                    }
                }
                $root = New-FixtureTree -Structure $structure
                $selected = $root | Select-TreeItem -Flatten
                $selected.Count | Should -Be 4
                $selected[0].Name | Should -Be "Root"
            }
        }

        It "Handles -NoRoot" {
            InModuleScope ShowTree {
                . (Join-Path $PSScriptRoot "..\..\Fixtures\TreeItemFixtures.ps1")
                $structure = [ordered]@{
                    "Root" = [ordered]@{
                        "DirA" = [ordered]@{
                            "FileA1.txt" = $null
                        }
                        "FileRoot.txt" = $null
                    }
                }
                $root = New-FixtureTree -Structure $structure
                $selected = $root | Select-TreeItem -NoRoot
                # Should return DirA, FileA1.txt, FileRoot.txt (Root is skipped)
                $selected.Count | Should -Be 3
                $selected[0].Name | Should -Be "DirA"
                $selected[1].Name | Should -Be "FileA1.txt"
                $selected[2].Name | Should -Be "FileRoot.txt"
            }
        }
    }

    Context "Slicing" {
        BeforeAll {
            $script:ModuleUnderTest = . "$PSScriptRoot\..\..\Helpers\Import-ModuleUnderTest.ps1" `
                -StartPath $PSScriptRoot `
                -ModuleName 'ShowTree' `
                -SourceRootName 'src' `
                -Exclude 'src/Tests/*' `
                -PassThru

            . (Join-Path $PSScriptRoot "..\..\Fixtures\TreeItemFixtures.ps1")
        }

        It "Handles -First" {
            InModuleScope ShowTree {
                . (Join-Path $PSScriptRoot "..\..\Fixtures\TreeItemFixtures.ps1")
                $items = 1..10 | ForEach-Object { New-FixtureTreeItem -Name "File$_.txt" }
                $selected = $items | Select-TreeItem -First 3
                $selected.Count | Should -Be 3
                $selected[0].Name | Should -Be "File1.txt"
                $selected[2].Name | Should -Be "File3.txt"
            }
        }

        It "Handles -Skip" {
            InModuleScope ShowTree {
                . (Join-Path $PSScriptRoot "..\..\Fixtures\TreeItemFixtures.ps1")
                $items = 1..10 | ForEach-Object { New-FixtureTreeItem -Name "File$_.txt" }
                $selected = $items | Select-TreeItem -Skip 8
                $selected.Count | Should -Be 2
                $selected[0].Name | Should -Be "File9.txt"
                $selected[1].Name | Should -Be "File10.txt"
            }
        }
    }
}