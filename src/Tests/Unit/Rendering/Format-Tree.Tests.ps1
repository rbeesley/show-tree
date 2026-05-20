# src\Tests\Unit\Rendering\Format-Tree.Tests.ps1

Describe "Format-Tree" {
    BeforeAll {
        $script:ModuleUnderTest = . "$PSScriptRoot\..\..\Helpers\Import-ModuleUnderTest.ps1" `
            -StartPath $PSScriptRoot `
            -ModuleName 'ShowTree' `
            -SourceRootName 'src' `
            -Exclude 'src/Tests/*' `
            -PassThru
    }

    Context "Basic Rendering" {
        It "Renders a single file" {
            InModuleScope ShowTree {
                . (Join-Path $script:moduleSrcRoot "Tests\Fixtures\TreeItemFixtures.ps1")
                . (Join-Path $script:moduleSrcRoot "Tests\Helpers\PrivateHelpers.ps1")

                $item = New-FixtureTreeItem -Name "File.txt"
                $out = @($item | Format-Tree -Mode 'Normal')
                $out[0] | Should -Be "╙── File.txt"
            }
        }


        It "Renders a directory with a file" {
            InModuleScope ShowTree {
                . (Join-Path $script:moduleSrcRoot "Tests\Fixtures\TreeItemFixtures.ps1")
                . (Join-Path $script:moduleSrcRoot "Tests\Helpers\PrivateHelpers.ps1")

                $structure = [ordered]@{
                    "Root" = [ordered]@{
                        "File1.txt" = $null
                    }
                }
                $root = New-FixtureTree -Structure $structure
                $items = $root | Select-TreeItem -Expand Descendants
                $out = @($items | Format-Tree -Mode 'Normal')

                $out.Count | Should -Be 2
                $out[0] | Should -Be "╚══ Root"
                $out[1] | Should -Be "    ╙── File1.txt"
            }
        }

        It "Renders multiple levels" {
            InModuleScope ShowTree {
                . (Join-Path $script:moduleSrcRoot "Tests\Fixtures\TreeItemFixtures.ps1")
                . (Join-Path $script:moduleSrcRoot "Tests\Helpers\PrivateHelpers.ps1")

                $structure = [ordered]@{
                    "Root" = [ordered]@{
                        "SubDir" = [ordered]@{
                            "File1.txt" = $null
                        }
                    }
                }
                $root = New-FixtureTree -Structure $structure
                $items = $root | Select-TreeItem -Expand Descendants
                $out = @($items | Format-Tree -Mode 'Normal')

                # In Normal mode, single root subtrees don't get a tail gap if they are the last item
                $out.Count | Should -Be 3
                $out[0] | Should -Be "╚══ Root"
                $out[1] | Should -Be "    ╚══ SubDir"
                $out[2] | Should -Be "        ╙── File1.txt"
            }
        }

        It "Renders a simple nested graph correctly" {
            InModuleScope ShowTree {
                . (Join-Path $script:moduleSrcRoot "Tests\Fixtures\TreeItemFixtures.ps1")
                . (Join-Path $script:moduleSrcRoot "Tests\Helpers\PrivateHelpers.ps1")

                $structure = [ordered]@{
                    "DirA" = [ordered]@{
                        "FileA1.txt" = $null
                    }
                    "DirB" = [ordered]@{
                        "FileB1.txt" = $null
                    }
                    "FileRoot.txt" = $null
                }
                $root = New-FixtureTree -Structure $structure
                
                # Simulate piping Get-TreeItem output (pre-ordered flat stream)
                # Skip the "Root" container itself to match common user usage: Get-TreeItem | Format-Tree
                $flatItems = $root | Select-TreeItem -Flatten

                $output = @($flatItems | Format-Tree -Mode 'Normal')

                # Expected graphical output:
                # ╠══ DirA
                # ║   ╙── FileA1.txt
                # ║
                # ╠══ DirB
                # ║   ╙── FileB1.txt
                # ║
                # ╙── FileRoot.txt

                $expected = @(
                    "╠══ DirA"
                    "║   ╙── FileA1.txt"
                    "║"
                    "╠══ DirB"
                    "║   ╙── FileB1.txt"
                    "║"
                    "╙── FileRoot.txt"
                )

                for ($i = 0; $i -lt [Math]::Max($output.Count, $expected.Count); $i++) {
                    $expectedLine = $expected[$i]
                    $output[$i] | Should -Be $expectedLine -ErrorAction Continue
                }

                $output.Count | Should -Be $expected.Count
            }
        }
    }


    Context "Modes and Styles" {
#        It "Renders in Tree.com mode" {
#            InModuleScope ShowTree {
#                . (Join-Path $script:moduleSrcRoot "Tests\Fixtures\TreeItemFixtures.ps1")
#                . (Join-Path $script:moduleSrcRoot "Tests\Helpers\PrivateHelpers.ps1")
#
#                $item = New-FixtureTreeItem -Name "File.txt"
#                $out = @($item | Format-Tree -Mode 'Tree')
#
#                $out[0] | Should -Be "    File.txt"
#            }
#        }

#        It "Renders directory in Tree.com mode" {
#            InModuleScope ShowTree {
#                . (Join-Path $script:moduleSrcRoot "Tests\Fixtures\TreeItemFixtures.ps1")
#                . (Join-Path $script:moduleSrcRoot "Tests\Helpers\PrivateHelpers.ps1")
#
#                $structure = [ordered]@{
#                    "Dir" = [ordered]@{
#                        "File.txt" = $null
#                        "SubDir" = [ordered]@{ }
#                    }
#                }
#                $root = New-FixtureTree -Structure $structure
#                $items = $root | Select-TreeItem -Expand Descendants
#                $out = @($items | Format-Tree -Mode 'Tree' -NoGap)
#
#                $out[0] | Should -Be "└───Dir"
#                $out[1] | Should -Be "    │   File.txt"
#                $out[2] | Should -Be "    │"
#                $out[3] | Should -Be "    └───SubDir"
#            }
#        }

        It "Renders in ASCII mode" {
            InModuleScope ShowTree {
                . (Join-Path $script:moduleSrcRoot "Tests\Fixtures\TreeItemFixtures.ps1")
                . (Join-Path $script:moduleSrcRoot "Tests\Helpers\PrivateHelpers.ps1")

                $item = New-FixtureTreeItem -Name "File.txt"
                $out = @($item | Format-Tree -Mode 'Normal' -Ascii)

                $out[0] | Should -Be "\-- File.txt"
            }
        }

        It "Renders in List mode" {
            InModuleScope ShowTree {
                . (Join-Path $script:moduleSrcRoot "Tests\Fixtures\TreeItemFixtures.ps1")
                . (Join-Path $script:moduleSrcRoot "Tests\Helpers\PrivateHelpers.ps1")

                $structure = [ordered]@{
                    "Root" = [ordered]@{
                        "File1.txt" = $null
                    }
                }
                $root = New-FixtureTree -Structure $structure
                $items = $root | Select-TreeItem -Expand Descendants
                $out = @($items | Format-Tree -Mode 'List')

                $out[0] | Should -Be " Root"
                $out[1] | Should -Be "  File1.txt"
            }
        }
    }

    Context "Links" {
        It "Renders symlink targets when requested" {
            InModuleScope ShowTree {
                . (Join-Path $script:moduleSrcRoot "Tests\Fixtures\TreeItemFixtures.ps1")
                . (Join-Path $script:moduleSrcRoot "Tests\Helpers\PrivateHelpers.ps1")

                $item = New-FixtureTreeItem -Name "Link" -IsSymlink $true -Target "C:\Target"
                $out = @($item | Format-Tree -ShowTargets)

                $out[0] | Should -Be "╙── Link -> C:\Target"
            }
        }
    }

    Context "Style Profile Path Handling" {
        It "Accepts a file path for StyleProfile" {
            InModuleScope ShowTree {
                . (Join-Path $script:moduleSrcRoot "Tests\Fixtures\TreeItemFixtures.ps1")
                . (Join-Path $script:moduleSrcRoot "Tests\Helpers\PrivateHelpers.ps1")

                $styleProfilePath = Join-Path $script:moduleSrcRoot "Data\DefaultStyleProfile.psd1"
                $item = New-FixtureTreeItem -Name "File.txt"
                $out = @($item | Format-Tree -StyleProfile $styleProfilePath)

                $out[0] | Should -Be "╙── File.txt"
            }
        }
    }

    Context "Streaming and Graphs" {
        It "Correctly handles a stream of items where some are children of others" {
            InModuleScope ShowTree {
                . (Join-Path $script:moduleSrcRoot "Tests\Fixtures\TreeItemFixtures.ps1")
                . (Join-Path $script:moduleSrcRoot "Tests\Helpers\PrivateHelpers.ps1")

                $structure = [ordered]@{
                    "Root" = [ordered]@{
                        "File1.txt" = $null
                    }
                }
                $root = New-FixtureTree -Structure $structure
                $file1 = $root.Children[0]

                $items = $root | Select-TreeItem -Expand Descendants
                $out = @($items | Format-Tree -Mode 'Normal')

                $out.Count | Should -Be 2
                $out[0] | Should -Be "╚══ Root"
                $out[1] | Should -Be "    ╙── File1.txt"
            }
        }


        It "Correctly handles multiple root items" {
            InModuleScope ShowTree {
                . (Join-Path $script:moduleSrcRoot "Tests\Fixtures\TreeItemFixtures.ps1")
                . (Join-Path $script:moduleSrcRoot "Tests\Helpers\PrivateHelpers.ps1")

                $item1 = New-FixtureTreeItem -Name "File1.txt"
                $item2 = New-FixtureTreeItem -Name "File2.txt"

                $out = @($item1, $item2 | Format-Tree -Mode 'Normal')

                $out.Count | Should -Be 2
                $out[0] | Should -Be "╟── File1.txt"
                $out[1] | Should -Be "╙── File2.txt"
            }
        }

#        It "Renders a cousin gap between major root groups in Normal mode" {
#            InModuleScope ShowTree {
#                . (Join-Path $script:moduleSrcRoot "Tests\Fixtures\TreeItemFixtures.ps1")
#                
#                # Root structure:
#                # Directories
#                #   SubDir
#                # Files
#                #   File.txt
#
#                $subDir = New-FixtureTreeItem -Name "SubDir" -IsDirectory $true
#                $directories = New-FixtureTreeItem -Name "Directories" -IsDirectory $true -Children @($subDir)
#                $subDir.ParentPath = $directories.FullPath
#
#                $file = New-FixtureTreeItem -Name "File.txt" -IsDirectory $false
#                $files = New-FixtureTreeItem -Name "Files" -IsDirectory $true -Children @($file)
#                $file.ParentPath = $files.FullPath
#
#                # Pipe them in as a stream
#                $in = @($directories, $subDir, $files, $file)
#                $out = @($in | Format-Tree -Mode 'Normal')
#
#                # Expected output (Unicode):
#                # ╠══ Directories
#                # ║   ╚══ SubDir
#                # ║
#                # ╚══ Files
#                #     ╙── File.txt
#
#                # Write-Host "[DEBUG_LOG] Output lines:"
#                # $out | ForEach-Object { Write-Host "[DEBUG_LOG] '$_'" }
#
#                $out.Count | Should -Be 5
#                $out[0] | Should -Be "╠══ Directories"
#                $out[1] | Should -Be "║   ╚══ SubDir"
#                $out[2] | Should -Be "║"
#                $out[3] | Should -Be "╚══ Files"
#                $out[4] | Should -Be "    ╙── File.txt"
#            }
#        }

        It "Does not render a gap when children are filtered out (DirectoryOnly scenario)" {
            InModuleScope ShowTree {
                . (Join-Path $script:moduleSrcRoot "Tests\Fixtures\TreeItemFixtures.ps1")

                # Structure:
                # Private (Container, has child file filtered out)
                # Public (Container)
                
                # In the real scenario, Get-TreeItem -DirectoryOnly outputs Private and Public.
                # Private.Children might still have the file, but the file is NOT in the stream.
                
                $file = New-FixtureTreeItem -Name "dummy.ps1" -IsDirectory $false
                $private = New-FixtureTreeItem -Name "Private" -IsDirectory $true -Children @($file)
                $file.ParentPath = $private.FullPath
                $public = New-FixtureTreeItem -Name "Public" -IsDirectory $true
                
                # Stream only contains Private and Public
                $in = @($private, $public)
                $out = @($in | Format-Tree -Mode 'Normal')
                
                # Expected (Unicode):
                # ╠══ Private
                # ╚══ Public
                # NO gap because Private has no children in the stream.
                
                $out.Count | Should -Be 2
                $out[0] | Should -Be "╠══ Private"
                $out[1] | Should -Be "╚══ Public"
            }
        }

#        It "Renders a gap between files and directories at the same level" {
#            InModuleScope ShowTree {
#                . (Join-Path $script:moduleSrcRoot "Tests\Fixtures\TreeItemFixtures.ps1")
#                
#                # Structure:
#                # Root
#                #   File1.txt
#                #   (gap here)
#                #   Dir1
#                #     File2.txt
#
#                $file1 = New-FixtureTreeItem -Name "File1.txt" -IsDirectory $false
#                $file2 = New-FixtureTreeItem -Name "File2.txt" -IsDirectory $false
#                $dir1 = New-FixtureTreeItem -Name "Dir1" -IsDirectory $true -Children @($file2)
#                $file2.ParentPath = $dir1.FullPath
#                
#                $root = New-FixtureTreeItem -Name "Root" -IsDirectory $true -Children @($file1, $dir1)
#                $file1.ParentPath = $root.FullPath
#                $dir1.ParentPath = $root.FullPath
#
#                $items = $root | Select-TreeItem -Expand Descendants
#                $out = @($items | Format-Tree -Mode 'Normal')
#
#                # Expected lines:
#                # ╚══ Root
#                #     ╟── File1.txt
#                #     ║
#                #     ╚══ Dir1
#                #         ╙── File2.txt
#
#                $out[0] | Should -Be "╚══ Root"
#                $out[1] | Should -Be "    ╟── File1.txt"
#                $out[2] | Should -Be "    ║"
#                $out[3] | Should -Be "    ╚══ Dir1"
#                $out[4] | Should -Be "        ╙── File2.txt"
#            }
#        }
    }
}
