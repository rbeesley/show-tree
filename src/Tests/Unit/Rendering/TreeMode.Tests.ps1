# src\Tests\Unit\Rendering\TreeMode.Tests.ps1

BeforeAll {
    $script:ModuleUnderTest = . "$PSScriptRoot\..\..\Helpers\Import-ModuleUnderTest.ps1" `
        -StartPath $PSScriptRoot `
        -ModuleName 'ShowTree' `
        -SourceRootName 'src' `
        -Exclude 'src/Tests/*' `
        -PassThru

    InModuleScope ShowTree {
        $script:testStyleProfile = Get-ShowTreeStyleProfile
        
        function script:Find-FixtureNodeByPath
        {
            param(
                [Parameter(Mandatory)]
                $Root,

                [Parameter(Mandatory)]
                [string]$Path
            )

            if ($Root.FullPath -eq $Path)
            {
                return $Root
            }

            foreach ($child in $Root.Children)
            {
                if ($child.FullPath -eq $Path)
                {
                    return $child
                }

                if ($child.IsContainer)
                {
                    $found = Find-FixtureNodeByPath -Root $child -Path $Path
                    if ($null -ne $found)
                    {
                        return $found
                    }
                }
            }

            return $null
        }
    }
}

Describe "Tree mode formatting" {
    It "Formats a simple TreeItem graph using Tree.com-compatible directory and file layout" {
        InModuleScope ShowTree {
            . (Join-Path $script:moduleSrcRoot "Tests\Fixtures\TreeItemFixtures.ps1")

            $structure = [ordered]@{
                a = [ordered]@{
                    a1 = $null
                    a2 = $null
                }
                b = [ordered]@{
                    b1 = $null
                }
            }

            $items = New-FixtureTree -Structure $structure | Select-TreeItem -Flatten

            $output = @($items | Format-Tree -Mode Tree)

            $output | Should -Be @(
                "├───a"
                "│       a1"
                "│       a2"
                "│"
                "└───b"
                "        b1"
            )
        }
    }

    It "Keeps continuation bars for later root-level siblings while rendering nested files without file connectors" {
        InModuleScope ShowTree {
            . (Join-Path $script:moduleSrcRoot "Tests\Fixtures\TreeItemFixtures.ps1")

            $structure = [ordered]@{
                a = [ordered]@{
                    aa = $null
                    ab = [ordered]@{
                        ab1 = $null
                    }
                }
                b = [ordered]@{
                    b1 = $null
                }
            }

            $items = New-FixtureTree -Structure $structure | Select-TreeItem -Flatten

            $output = @($items | Format-Tree -Mode Tree)

            $output | Should -Be @(
                "├───a"
                "│   │   aa"
                "│   │"
                "│   └───ab"
                "│           ab1"
                "│"
                "└───b"
                "        b1"
            )
        }
    }

    It "Renders gap lines in Tree mode" {
        InModuleScope ShowTree {
            . (Join-Path $script:moduleSrcRoot "Tests\Fixtures\TreeItemFixtures.ps1")

            $structure = [ordered]@{
                a = [ordered]@{
                    a1 = $null
                }
                b = [ordered]@{
                    b1 = $null
                }
            }

            $items = New-FixtureTree -Structure $structure | Select-TreeItem -Flatten

            $output = @($items | Format-Tree -Mode Tree)

            $output | Should -Be @(
                "├───a"
                "│       a1"
                "│"
                "└───b"
                "        b1"
            )
        }
    }

    It "Supports ASCII Tree mode connectors" {
        InModuleScope ShowTree {
            . (Join-Path $script:moduleSrcRoot "Tests\Fixtures\TreeItemFixtures.ps1")

            $structure = [ordered]@{
                a = [ordered]@{
                    a1 = $null
                }
                b = [ordered]@{
                    b1 = $null
                }
            }

            $items = New-FixtureTree -Structure $structure | Select-TreeItem -Flatten

            $output = @($items | Format-Tree -Mode Tree -Ascii)

            $output | Should -Be @(
                "+---a"
                "|       a1"
                "|"
                "\---b"
                "        b1"
            )
        }
    }

    It "Formats a file-only root-level listing like Tree.com when there are no later root directories" {
        InModuleScope ShowTree {
            . (Join-Path $script:moduleSrcRoot "Tests\Fixtures\TreeItemFixtures.ps1")

            $structure = [ordered]@{
                file1 = $null
                file2 = $null
            }

            $items = New-FixtureTree -Structure $structure | Select-TreeItem -Flatten

            $output = @($items | Format-Tree -Mode Tree)

            $output | Should -Be @(
                "    file1"
                "    file2"
            )
        }
    }

    It "renders root files with Tree.com file connector spans when later root directories exist" {
        InModuleScope ShowTree {
            . (Join-Path $script:moduleSrcRoot "Tests\Fixtures\TreeItemFixtures.ps1")

            $structure = [ordered]@{
                "root-file-1.txt" = $null
                "root-file-2.txt" = $null
                "dir" = [ordered]@{
                    "child-file.txt" = $null
                }
            }

            $items = New-FixtureTree -Structure $structure | Select-TreeItem -Flatten

            $output = @($items | Format-Tree -Mode Tree)

            $output | Should -Be @(
                "│   root-file-1.txt"
                "│   root-file-2.txt"
                "│"
                "└───dir"
                "        child-file.txt"
            )
        }
    }

    It "Renders Tree.com file connector spans only when a later sibling directory exists" {
        InModuleScope ShowTree {
            . (Join-Path $script:moduleSrcRoot "Tests\Fixtures\TreeItemFixtures.ps1")

            $structure = [ordered]@{
                a = [ordered]@{
                    "a-file-1.txt" = $null
                    "a-file-2.txt" = $null
                    aa = [ordered]@{
                        "aa-file.txt" = $null
                    }
                }
                b = [ordered]@{
                    "b-file.txt" = $null
                }
            }

            $items = New-FixtureTree -Structure $structure | Select-TreeItem -Flatten

            $output = @($items | Format-Tree -Mode Tree)

            $output | Should -Be @(
                "├───a"
                "│   │   a-file-1.txt"
                "│   │   a-file-2.txt"
                "│   │"
                "│   └───aa"
                "│           aa-file.txt"
                "│"
                "└───b"
                "        b-file.txt"
            )
        }
    }
}

Describe "Show-Tree Tree mode gap policy" -Skip:(-not $IsWindows) {
    It "does not show gap lines in directory-only Tree mode by default" {
        InModuleScope ShowTree {
            $rootPath = 'C:\Test'

            Mock Get-TreeModeHeader {
                @(
                    'Folder PATH listing for volume Test'
                    'Volume serial number is 0000-0000'
                    $Path
                )
            }

            Mock Get-RawDirectoryEntries {
                param(
                    [string]$Path,
                    [int]$Depth
                )

                if ($Path -eq $rootPath) {
                    return [pscustomobject]@{
                        Files = @()
                        Directories = @(
                            New-TreeItem -FullPath (Join-Path $Path 'a') -Name 'a' -Kind Directory -IsContainer $true -Depth $Depth -ParentPath $Path
                            New-TreeItem -FullPath (Join-Path $Path 'b') -Name 'b' -Kind Directory -IsContainer $true -Depth $Depth -ParentPath $Path
                        )
                    }
                }

                if ($Path -eq (Join-Path $rootPath 'a')) {
                    return [pscustomobject]@{
                        Files = @()
                        Directories = @(
                            New-TreeItem -FullPath (Join-Path $Path 'aa') -Name 'aa' -Kind Directory -IsContainer $true -Depth $Depth -ParentPath $Path
                        )
                    }
                }

                return [pscustomobject]@{
                    Files       = @()
                    Directories = @()
                }
            }

            $output = @(Show-Tree $rootPath -Mode Tree)

            $output | Should -Be @(
                'Folder PATH listing for volume Test'
                'Volume serial number is 0000-0000'
                'C:\Test'
                '├───a'
                '│   └───aa'
                '└───b'
            )
        }
    }

    It "shows gap lines in Tree mode when -Gap is explicitly requested" {
        InModuleScope ShowTree {
            $rootPath = 'C:\Test'

            Mock Get-TreeModeHeader {
                @(
                    'Folder PATH listing for volume Test'
                    'Volume serial number is 0000-0000'
                    $Path
                )
            }

            Mock Get-RawDirectoryEntries {
                param(
                    [string]$Path,
                    [int]$Depth
                )

                if ($Path -eq $rootPath) {
                    return [pscustomobject]@{
                        Files = @()
                        Directories = @(
                            New-TreeItem -FullPath (Join-Path $Path 'a') -Name 'a' -Kind Directory -IsContainer $true -Depth $Depth -ParentPath $Path
                            New-TreeItem -FullPath (Join-Path $Path 'b') -Name 'b' -Kind Directory -IsContainer $true -Depth $Depth -ParentPath $Path
                        )
                    }
                }

                if ($Path -eq (Join-Path $rootPath 'a')) {
                    return [pscustomobject]@{
                        Files = @()
                        Directories = @(
                            New-TreeItem -FullPath (Join-Path $Path 'aa') -Name 'aa' -Kind Directory -IsContainer $true -Depth $Depth -ParentPath $Path
                        )
                    }
                }

                return [pscustomobject]@{
                    Files       = @()
                    Directories = @()
                }
            }

            $output = @(Show-Tree $rootPath -Mode Tree -Gap)

            $output | Should -Be @(
                'Folder PATH listing for volume Test'
                'Volume serial number is 0000-0000'
                'C:\Test'
                '├───a'
                '│   └───aa'
                '│'
                '└───b'
            )
        }
    }

    It "shows gap lines in Tree mode when -Files is specified" {
        InModuleScope ShowTree {
            $rootPath = 'C:\Test'

            Mock Get-TreeModeHeader {
                @(
                    'Folder PATH listing for volume Test'
                    'Volume serial number is 0000-0000'
                    $Path
                )
            }

            Mock Get-RawDirectoryEntries {
                param(
                    [string]$Path,
                    [int]$Depth
                )

                if ($Path -eq $rootPath) {
                    return [pscustomobject]@{
                        Files = @()
                        Directories = @(
                            New-TreeItem -FullPath (Join-Path $Path 'a') -Name 'a' -Kind Directory -IsContainer $true -Depth $Depth -ParentPath $Path
                            New-TreeItem -FullPath (Join-Path $Path 'b') -Name 'b' -Kind Directory -IsContainer $true -Depth $Depth -ParentPath $Path
                        )
                    }
                }

                if ($Path -eq (Join-Path $rootPath 'a')) {
                    return [pscustomobject]@{
                        Files = @(
                            New-TreeItem -FullPath (Join-Path $Path 'file.txt') -Name 'file.txt' -Kind File -IsContainer $false -Depth $Depth -ParentPath $Path
                        )
                        Directories = @()
                    }
                }

                return [pscustomobject]@{
                    Files       = @()
                    Directories = @()
                }
            }

            $output = @(Show-Tree $rootPath -Mode Tree -Files)

            $output | Should -Be @(
                'Folder PATH listing for volume Test'
                'Volume serial number is 0000-0000'
                'C:\Test'
                '├───a'
                '│       file.txt'
                '│'
                '└───b'
            )
        }
    }
}

Describe "Tree mode Win32 provider mapping" -Skip:(-not $IsWindows) {
    It "Maps mocked Win32 provider output to a flattened TreeItem graph with correct depth and parent paths" {
        InModuleScope ShowTree {
            . (Join-Path $script:moduleSrcRoot "Tests\Fixtures\TreeItemFixtures.ps1")

            $rootPath = 'C:\Test'

            $rootChildren = New-FixtureTree -ParentPath $rootPath -Structure ([ordered]@{
                a = [ordered]@{
                    a1 = $null
                    a2 = $null
                }
                b = [ordered]@{
                    b1 = $null
                }
            })

            $fixtureRoot = New-TreeItem `
                -FullPath $rootPath `
                -Name 'Test' `
                -Kind Directory `
                -IsContainer $true `
                -Depth -1 `
                -ParentPath 'C:\' `
                -Children $rootChildren

            Mock Get-RawDirectoryEntries {
                param(
                    [string]$Path,
                    [int]$Depth
                )

                $node = Find-FixtureNodeByPath -Root $fixtureRoot -Path $Path

                if ($null -eq $node) {
                    return [pscustomobject]@{
                        Directories = @()
                        Files       = @()
                    }
                }

                foreach ($child in $node.Children) {
                    $child.Depth = $Depth
                    $child.ParentPath = $Path
                }

                [pscustomobject]@{
                    Directories = @($node.Children | Where-Object IsContainer)
                    Files       = @($node.Children | Where-Object { -not $_.IsContainer })
                }
            }

            $items = @(Get-TreeItem -Path $rootPath -ProviderMode Win32 -Depth 1)

            $items.Name | Should -Be @('a', 'a1', 'a2', 'b', 'b1')

            ($items | Where-Object Name -eq 'a').Depth | Should -Be 0
            ($items | Where-Object Name -eq 'a').ParentPath | Should -Be $rootPath

            ($items | Where-Object Name -eq 'a1').Depth | Should -Be 1
            ($items | Where-Object Name -eq 'a1').ParentPath | Should -Be (Join-Path $rootPath 'a')

            ($items | Where-Object Name -eq 'b').Depth | Should -Be 0
            ($items | Where-Object Name -eq 'b').ParentPath | Should -Be $rootPath

            ($items | Where-Object Name -eq 'b1').Depth | Should -Be 1
            ($items | Where-Object Name -eq 'b1').ParentPath | Should -Be (Join-Path $rootPath 'b')
        }
    }

    It "Produces Tree.com-compatible rendering from mocked Win32 provider output" {
        InModuleScope ShowTree {
            . (Join-Path $script:moduleSrcRoot "Tests\Fixtures\TreeItemFixtures.ps1")

            $rootPath = 'C:\Test'

            $rootChildren = New-FixtureTree -ParentPath $rootPath -Structure ([ordered]@{
                a = [ordered]@{
                    a1 = $null
                    a2 = $null
                }
                b = [ordered]@{
                    b1 = $null
                }
            })

            $fixtureRoot = New-TreeItem `
                -FullPath $rootPath `
                -Name 'Test' `
                -Kind Directory `
                -IsContainer $true `
                -Depth -1 `
                -ParentPath 'C:\' `
                -Children $rootChildren

            Mock Get-RawDirectoryEntries {
                param(
                    [string]$Path,
                    [int]$Depth
                )

                $node = Find-FixtureNodeByPath -Root $fixtureRoot -Path $Path

                if ($null -eq $node) {
                    return [pscustomobject]@{
                        Directories = @()
                        Files       = @()
                    }
                }

                foreach ($child in $node.Children) {
                    $child.Depth = $Depth
                    $child.ParentPath = $Path
                }

                [pscustomobject]@{
                    Directories = @($node.Children | Where-Object IsContainer)
                    Files       = @($node.Children | Where-Object { -not $_.IsContainer })
                }
            }

            $items = Get-TreeItem -Path $rootPath -ProviderMode Win32 -Depth 1
            $output = @($items | Format-Tree -Mode Tree)

            $output | Should -Be @(
                "├───a"
                "│       a1"
                "│       a2"
                "│"
                "└───b"
                "        b1"
            )
        }
    }

    It "Passes recursion depth into the mocked Win32 provider" {
        InModuleScope ShowTree {
            . (Join-Path $script:moduleSrcRoot "Tests\Fixtures\TreeItemFixtures.ps1")

            $rootPath = 'C:\Test'
            $observedCalls = [System.Collections.Generic.List[object]]::new()

            $rootChildren = New-FixtureTree -ParentPath $rootPath -Structure ([ordered]@{
                a = [ordered]@{
                    a1 = $null
                }
            })

            $fixtureRoot = New-TreeItem `
                -FullPath $rootPath `
                -Name 'Test' `
                -Kind Directory `
                -IsContainer $true `
                -Depth -1 `
                -ParentPath 'C:\' `
                -Children $rootChildren

            Mock Get-RawDirectoryEntries {
                param(
                    [string]$Path,
                    [int]$Depth
                )

                $observedCalls.Add([pscustomobject]@{
                    Path  = $Path
                    Depth = $Depth
                })

                $node = Find-FixtureNodeByPath -Root $fixtureRoot -Path $Path

                if ($null -eq $node) {
                    return [pscustomobject]@{
                        Directories = @()
                        Files       = @()
                    }
                }

                foreach ($child in $node.Children) {
                    $child.Depth = $Depth
                    $child.ParentPath = $Path
                }

                [pscustomobject]@{
                    Directories = @($node.Children | Where-Object IsContainer)
                    Files       = @($node.Children | Where-Object { -not $_.IsContainer })
                }
            }

            $null = @(Get-TreeItem -Path $rootPath -ProviderMode Win32 -Depth 1)

            $observedCalls.Count | Should -Be 2

            $observedCalls[0].Path | Should -Be $rootPath
            $observedCalls[0].Depth | Should -Be 0

            $observedCalls[1].Path | Should -Be (Join-Path $rootPath 'a')
            $observedCalls[1].Depth | Should -Be 1
        }
    }

    It "Honors DirectoryOnly while still recursing through directories from mocked Win32 output" {
        InModuleScope ShowTree {
            . (Join-Path $script:moduleSrcRoot "Tests\Fixtures\TreeItemFixtures.ps1")

            $rootPath = 'C:\Test'

            $rootChildren = New-FixtureTree -ParentPath $rootPath -Structure ([ordered]@{
                a = [ordered]@{
                    a1 = $null
                }
                rootFile = $null
            })

            $fixtureRoot = New-TreeItem `
                -FullPath $rootPath `
                -Name 'Test' `
                -Kind Directory `
                -IsContainer $true `
                -Depth -1 `
                -ParentPath 'C:\' `
                -Children $rootChildren

            Mock Get-RawDirectoryEntries {
                param(
                    [string]$Path,
                    [int]$Depth
                )

                $node = Find-FixtureNodeByPath -Root $fixtureRoot -Path $Path

                if ($null -eq $node) {
                    return [pscustomobject]@{
                        Directories = @()
                        Files       = @()
                    }
                }

                foreach ($child in $node.Children) {
                    $child.Depth = $Depth
                    $child.ParentPath = $Path
                }

                [pscustomobject]@{
                    Directories = @($node.Children | Where-Object IsContainer)
                    Files       = @($node.Children | Where-Object { -not $_.IsContainer })
                }
            }

            $items = @(Get-TreeItem -Path $rootPath -ProviderMode Win32 -Depth 1 -DirectoryOnly)

            $items.Name | Should -Be @('a')
            $items.Name | Should -Not -Contain 'rootFile'
            $items.Name | Should -Not -Contain 'a1'
        }
    }
}

Describe "Tree mode Win32 provider ordering" -Skip:(-not $IsWindows) {
    It "preserves tree.com-compatible Win32 ordering without applying deterministic sorting" {
        InModuleScope ShowTree {
            $rootPath = 'C:\Test'

            Mock Get-RawDirectoryEntries {
                param(
                    [string]$Path,
                    [int]$Depth
                )

                if ($Path -eq $rootPath) {
                    return [pscustomobject]@{
                        Files = @(
                            New-TreeItem -FullPath (Join-Path $Path 'z-file.txt') -Name 'z-file.txt' -Kind File -IsContainer $false -Depth $Depth -ParentPath $Path
                            New-TreeItem -FullPath (Join-Path $Path 'a-file.txt') -Name 'a-file.txt' -Kind File -IsContainer $false -Depth $Depth -ParentPath $Path
                        )
                        Directories = @(
                            New-TreeItem -FullPath (Join-Path $Path 'z-dir') -Name 'z-dir' -Kind Directory -IsContainer $true -Depth $Depth -ParentPath $Path
                            New-TreeItem -FullPath (Join-Path $Path 'a-dir') -Name 'a-dir' -Kind Directory -IsContainer $true -Depth $Depth -ParentPath $Path
                        )
                    }
                }

                return [pscustomobject]@{
                    Files       = @()
                    Directories = @()
                }
            }

            $items = @(Get-TreeItem -Path $rootPath -ProviderMode Win32 -Depth 0)

            $items.Name | Should -Be @(
                'z-file.txt'
                'a-file.txt'
                'z-dir'
                'a-dir'
            )
        }
    }
}