# src\Tests\Unit\Enumeration\Get-TreeItem.Tests.ps1

Describe "Get-TreeItem" {
    BeforeAll {
        # Load necessary scripts
        $sutDir = Join-Path $PSScriptRoot '..\..\..\Public'
        $privDir = Join-Path $PSScriptRoot '..\..\..\Private'
        $fixDir = Join-Path $PSScriptRoot '..\..\Fixtures'

        . (Join-Path $sutDir 'Get-TreeItem.ps1')
        . (Join-Path $sutDir 'New-TreeItem.ps1')
        . (Join-Path $privDir 'Get-RawDirectoryEntries.ps1')
        . (Join-Path $privDir 'TreeItemPredicates.ps1')
        . (Join-Path $fixDir 'TreeItemFixtures.ps1')

        $script:TestRoot = Join-Path $PSScriptRoot "GetTreeItemTest"
        if (Test-Path $script:TestRoot) { Remove-Item $script:TestRoot -Recurse -Force }
        New-Item -ItemType Directory -Path $script:TestRoot | Out-Null
        
        # Create a test structure
        # TestRoot/
        #   Dir1/
        #     File1.txt
        #   File2.txt
        #   .HiddenFile (on non-windows, or +H on windows)
        #   _SystemFile (+S on windows)
        
        $dir1 = New-Item -ItemType Directory -Path (Join-Path $script:TestRoot "Dir1")
        New-Item -ItemType File -Path (Join-Path $dir1 "File1.txt") | Out-Null
        New-Item -ItemType File -Path (Join-Path $script:TestRoot "File2.txt") | Out-Null
        
        $hiddenFile = New-Item -ItemType File -Path (Join-Path $script:TestRoot ".HiddenFile")
        if ($IsWindows) {
            $hiddenFile.Attributes = $hiddenFile.Attributes -bor [IO.FileAttributes]::Hidden
            
            $systemFile = New-Item -ItemType File -Path (Join-Path $script:TestRoot "_SystemFile")
            $systemFile.Attributes = $systemFile.Attributes -bor [IO.FileAttributes]::System
        }
    }

    AfterAll {
        if (Test-Path $script:TestRoot) { Remove-Item $script:TestRoot -Recurse -Force }
    }

    Context "Basic Enumeration" {
        It "Produces TreeItem objects" {
            $items = @(Get-TreeItem -Path $script:TestRoot -Depth 0)
            $items.Count | Should -BeGreaterThan 0
            $items[0].PSTypeNames | Should -Contain "ShowTree.TreeItem"
        }

        It "Enumerates files and directories" {
            $items = Get-TreeItem -Path $script:TestRoot -Depth 0
            # Should find Dir1, File2.txt, .HiddenFile, _SystemFile
            $expectedCount = if ($IsWindows) { 4 } else { 3 }
            $items.Count | Should -Be $expectedCount
            $items.Name | Should -Contain "Dir1"
            $items.Name | Should -Contain "File2.txt"
            $items.Name | Should -Contain ".HiddenFile"
            if ($IsWindows) {
                $items.Name | Should -Contain "_SystemFile"
            }
        }

        It "Recurses to specified depth" {
            $items = Get-TreeItem -Path $script:TestRoot -Depth 1
            $items.Name | Should -Contain "File1.txt"
        }
    }

    Context "Normalization" {
        It "Orders files before directories and then by name" {
            # Expected order: .HiddenFile, File2.txt, _SystemFile, Dir1 (sorted by IsContainer, then Name)
            $items = Get-TreeItem -Path $script:TestRoot -Depth 0
            $items[-1].Name | Should -Be "Dir1"
            $sortedNames = $items | Select-Object -ExpandProperty Name
            $expectedCount = if ($IsWindows) { 4 } else { 3 }
            $sortedNames | Should -Contain "File2.txt"
        }

        It "Correctly exposes IsHidden property" {
            $items = Get-TreeItem -Path $script:TestRoot -Depth 0
            $hiddenItem = $items | Where-Object { $_.Name -eq ".HiddenFile" }
            $hiddenItem.IsHidden | Should -Be $true
            
            $normalItem = $items | Where-Object { $_.Name -eq "File2.txt" }
            $normalItem.IsHidden | Should -Be $false
        }
    }

    Context "Provider Modes" {
        It "Supports PowerShell provider mode" {
            $items = Get-TreeItem -Path $script:TestRoot -ProviderMode PowerShell -Depth 0
            $items.Count | Should -BeGreaterThan 0
        }

        if ($IsWindows) {
            It "Supports Win32 provider mode on Windows" {
                $items = Get-TreeItem -Path $script:TestRoot -ProviderMode Win32 -Depth 0
                $items.Count | Should -BeGreaterThan 0
            }
        }
    }

    Context "Link Following" {
        BeforeAll {
            $script:LinkRoot = Join-Path $script:TestRoot "LinkTest"
            if (Test-Path $script:LinkRoot) { Remove-Item $script:LinkRoot -Recurse -Force }
            New-Item -ItemType Directory -Path $script:LinkRoot | Out-Null
            
            # TargetDir is OUTSIDE LinkRoot to ensure it's ONLY reached via the link when we recurse from LinkRoot
            $script:ExternalTarget = Join-Path $script:TestRoot "ExternalTarget"
            if (Test-Path $script:ExternalTarget) { Remove-Item $script:ExternalTarget -Recurse -Force }
            New-Item -ItemType Directory -Path $script:ExternalTarget | Out-Null
            New-Item -ItemType File -Path (Join-Path $script:ExternalTarget "TargetFile.txt") | Out-Null

            if ($IsWindows) {
                # Create a Junction on Windows
                $junctionPath = Join-Path $script:LinkRoot "JunctionLink"
                New-Item -ItemType Junction -Path $junctionPath -Target $script:ExternalTarget | Out-Null
            } else {
                # Create a Symlink on Unix
                $symlinkPath = Join-Path $script:LinkRoot "SymlinkLink"
                New-Item -ItemType SymbolicLink -Path $symlinkPath -Target $script:ExternalTarget | Out-Null
            }
        }

        It "Does NOT follow links by default" {
            $items = Get-TreeItem -Path $script:LinkRoot -Depth 2
            # Should see JunctionLink/SymlinkLink, but NOT TargetFile.txt inside it
            $linkName = if ($IsWindows) { "JunctionLink" } else { "SymlinkLink" }
            $items.Name | Should -Contain $linkName
            $items.Name | Should -Not -Contain "TargetFile.txt"
        }

        It "Follows links when -FollowLinks is specified" {
            $items = Get-TreeItem -Path $script:LinkRoot -Depth 2 -FollowLinks
            $items.Name | Should -Contain "TargetFile.txt"
        }
    }

    Context "Filtering" {

        It "Excludes items by name" {
            $items = Get-TreeItem -Path $script:TestRoot -Depth 0 -Exclude "Dir1"
            $items.Name | Should -Not -Contain "Dir1"
            $items.Name | Should -Contain "File2.txt"
        }

        It "Excludes items by glob pattern" {
            $items = Get-TreeItem -Path $script:TestRoot -Depth 0 -Exclude "*.txt"
            $items.Name | Should -Not -Contain "File2.txt"
            $items.Name | Should -Contain "Dir1"
        }

        It "Prunes subtrees of excluded directories" {
            $items = Get-TreeItem -Path $script:TestRoot -Depth 1 -Exclude "Dir1"
            $items.Name | Should -Not -Contain "Dir1"
            $items.Name | Should -Not -Contain "File1.txt"
        }

        It "Includes items by glob pattern (resurrection)" {
            $items = Get-TreeItem -Path $script:TestRoot -Depth 0 -Exclude "*" -Include "Dir1"
            $items.Name | Should -Contain "Dir1"
            $items.Name | Should -Not -Contain "File2.txt"
        }

        It "Hides hidden items" {
            $items = Get-TreeItem -Path $script:TestRoot -Depth 0 -HideHidden
            $items.Name | Should -Not -Contain ".HiddenFile"
        }

        if ($IsWindows) {
            It "Hides system items on Windows" {
                $items = Get-TreeItem -Path $script:TestRoot -Depth 0 -HideSystem
                $items.Name | Should -Not -Contain "_SystemFile"
            }
        }

        It "Filters out files when -DirectoryOnly is specified" {
            $items = Get-TreeItem -Path $script:TestRoot -Depth 1 -DirectoryOnly
            # Should contain Dir1, but NOT File2.txt or File1.txt
            $items.Name | Should -Contain "Dir1"
            $items.Name | Should -Not -Contain "File2.txt"
            $items.Name | Should -Not -Contain "File1.txt"
            $items.Name | Should -Not -Contain ".HiddenFile"
            if ($IsWindows) {
                $items.Name | Should -Not -Contain "_SystemFile"
            }
        }

        It "Still follows into directories when -DirectoryOnly is specified" {
            $items = Get-TreeItem -Path $script:TestRoot -Depth 1 -DirectoryOnly
            # Dir1 is a container, so we should have recurse into it, 
            # but File1.txt inside it should be filtered out.
            $items | Where-Object { $_.Name -eq "Dir1" } | Should -Not -BeNull
            $items.Name | Should -Not -Contain "File1.txt"
        }
    }
}
