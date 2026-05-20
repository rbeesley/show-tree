# src\Tests\Unit\Rendering\Gaps.Tests.ps1

BeforeAll {
    $script:ModuleUnderTest = . "$PSScriptRoot\..\..\Helpers\Import-ModuleUnderTest.ps1" `
        -StartPath $PSScriptRoot `
        -ModuleName 'ShowTree' `
        -SourceRootName 'src' `
        -Exclude 'src/Tests/*' `
        -PassThru
}

Describe "Reproduction Gaps" {
    Context "Base structures" {
        It "Doesn't have a gap with an empty root" {
            InModuleScope ShowTree {
                . (Join-Path $script:moduleSrcRoot "Tests\Fixtures\TreeItemFixtures.ps1")
                . (Join-Path $script:moduleSrcRoot "Tests\Helpers\PrivateHelpers.ps1")

                # Create a structure:
                # root

                $structure = [ordered]@{
                }
                $root = New-FixtureTree -Structure $structure

                $items = $root | Select-TreeItem -Flatten

                $output = $items | Format-Tree -Mode Normal

                # Expected:
                #  $null

                # We expect 0 lines.
                $output.Count | Should -Be 0
            }
        }

        It "Doesn't have a gap if there is only one file in the root" {
            InModuleScope ShowTree {
                . (Join-Path $script:moduleSrcRoot "Tests\Fixtures\TreeItemFixtures.ps1")
                . (Join-Path $script:moduleSrcRoot "Tests\Helpers\PrivateHelpers.ps1")

                # Create a structure:
                # root
                #  ╙── file1.txt

                $structure = [ordered]@{
                    "file1.txt" = $null
                }
                $root = New-FixtureTree -Structure $structure

                $items = $root | Select-TreeItem -Flatten

                $output = @($items | Format-Tree -Mode Normal -Colorize:$false)

                # Expected:
                #  ╙── file1.txt

                $output[0] | Should -Be "╙── file1.txt"

                # We expect 1 line: file1.txt.
                $output.Count | Should -Be 1
            }
        }

        It "Doesn't have a gap if there is only one directory in the root" {
            InModuleScope ShowTree {
                . (Join-Path $script:moduleSrcRoot "Tests\Fixtures\TreeItemFixtures.ps1")
                . (Join-Path $script:moduleSrcRoot "Tests\Helpers\PrivateHelpers.ps1")

                # Create a structure:
                # root
                #  ╚══ dir1

                $structure = [ordered]@{
                    "dir1" = [ordered]@{
                    }
                }
                $root = New-FixtureTree -Structure $structure

                $items = $root | Select-TreeItem -Flatten

                $output = @($items | Format-Tree -Mode Normal -Colorize:$false)

                # Expected:
                #  ╚══ dir1

                $output[0] | Should -Be "╚══ dir1"

                # We expect 1 line: dir1.
                $output.Count | Should -Be 1
            }
        }

        It "Doesn't have a gap if there are only files in the root" {
            InModuleScope ShowTree {
                . (Join-Path $script:moduleSrcRoot "Tests\Fixtures\TreeItemFixtures.ps1")
                . (Join-Path $script:moduleSrcRoot "Tests\Helpers\PrivateHelpers.ps1")

                # Create a structure:
                # root
                #  ╟── file1.txt
                #  ╙── file2.txt

                $structure = [ordered]@{
                    "file1.txt" = $null
                    "file2.txt" = $null
                }
                $root = New-FixtureTree -Structure $structure

                $items = $root | Select-TreeItem -Flatten

                $output = $items | Format-Tree -Mode Normal

                # Expected:
                #  ╟── file1.txt
                #  ╙── file2.txt

                $output[0] | Should -Be "╟── file1.txt"
                $output[1] | Should -Be "╙── file2.txt"

                # We expect 2 lines: file1.txt and file2.txt.
                $output.Count | Should -Be 2
            }
        }

        It "Has a gap if there are a mix of files and directories in the root" {
            InModuleScope ShowTree {
                . (Join-Path $script:moduleSrcRoot "Tests\Fixtures\TreeItemFixtures.ps1")
                . (Join-Path $script:moduleSrcRoot "Tests\Helpers\PrivateHelpers.ps1")

                # Create a structure:
                # root
                #  ╟── file1.txt
                #  ║
                #  ╚══ dir1

                $structure = [ordered]@{
                    "file1.txt" = $null
                    "dir1" = [ordered]@{
                    }
                }
                $root = New-FixtureTree -Structure $structure

                $items = $root | Select-TreeItem -Flatten

                $output = $items | Format-Tree -Mode Normal

                # Expected:
                #  ╟── file1.txt
                #  ║
                #  ╚══ dir1

                $output[0] | Should -Be "╟── file1.txt"
                $output[1] | Should -Be "║"
                $output[2] | Should -Be "╚══ dir1"

                # We expect 3 lines: file1.txt, a gap, and dir1.
                $output.Count | Should -Be 3
            }
        }

        It "Doesn't have a gap between sibling directories if the 1st sibling has no children" {
            InModuleScope ShowTree {
                . (Join-Path $script:moduleSrcRoot "Tests\Fixtures\TreeItemFixtures.ps1")
                . (Join-Path $script:moduleSrcRoot "Tests\Helpers\PrivateHelpers.ps1")

                # Create a structure:
                # root
                #  ╠══ dir1
                #  ╚══ dir2

                $structure = [ordered]@{
                    "dir1" = [ordered]@{
                    }
                    "dir2" = [ordered]@{
                    }
                }
                $root = New-FixtureTree -Structure $structure

                $items = $root | Select-TreeItem -Flatten

                $output = $items | Format-Tree -Mode Normal

                # Expected:
                #  ╠══ dir1
                #  ╚══ dir2

                $output[0] | Should -Be "╠══ dir1"
                $output[1] | Should -Be "╚══ dir2"

                # We expect 2 lines: dir1 and dir2.
                $output.Count | Should -Be 2
            }
        }

        It "Doesn't have a gap between the parent and child directories if the parent has no children" {
            InModuleScope ShowTree {
                . (Join-Path $script:moduleSrcRoot "Tests\Fixtures\TreeItemFixtures.ps1")
                . (Join-Path $script:moduleSrcRoot "Tests\Helpers\PrivateHelpers.ps1")

                # Create a structure:
                # root
                #  ╚══ dir1
                #      ╚══ dir1_1

                $structure = [ordered]@{
                    "dir1" = [ordered]@{
                        "dir1_1" = [ordered]@{
                        }
                    }
                }
                $root = New-FixtureTree -Structure $structure

                $items = $root | Select-TreeItem -Flatten

                $output = $items | Format-Tree -Mode Normal

                # Expected:
                #  ╚══ dir1
                #      ╚══ dir1_1

                $output[0] | Should -Be "╚══ dir1"
                $output[1] | Should -Be "    ╚══ dir1_1"

                # We expect 2 lines: dir1 and dir1_1.
                $output.Count | Should -Be 2
            }
        }

        It "Doesn't have a gap if there are only files in subdirectories" {
            InModuleScope ShowTree {
                . (Join-Path $script:moduleSrcRoot "Tests\Fixtures\TreeItemFixtures.ps1")
                . (Join-Path $script:moduleSrcRoot "Tests\Helpers\PrivateHelpers.ps1")

                # Create a structure:
                # root
                #  ╚══ dir1
                #      ╟── file1_1.txt
                #      ╙── file1_2.txt

                $structure = [ordered]@{
                    "dir1" = [ordered]@{
                        "file1_1.txt" = $null
                        "file1_2.txt" = $null
                    }
                }
                $root = New-FixtureTree -Structure $structure

                $items = $root | Select-TreeItem -Flatten

                $output = $items | Format-Tree -Mode Normal

                # Expected:
                #  ╚══ dir1
                #      ╟── file1_1.txt
                #      ╙── file1_2.txt

                $output[0] | Should -Be "╚══ dir1"
                $output[1] | Should -Be "    ╟── file1_1.txt"
                $output[2] | Should -Be "    ╙── file1_2.txt"

                # We expect 3 lines: dir1, file1_1.txt, and file1_2.txt.
                $output.Count | Should -Be 3
            }
        }

        It "Has a gap between the mixed sibling files and directories in subdirectories" {
            InModuleScope ShowTree {
                . (Join-Path $script:moduleSrcRoot "Tests\Fixtures\TreeItemFixtures.ps1")
                . (Join-Path $script:moduleSrcRoot "Tests\Helpers\PrivateHelpers.ps1")

                # Create a structure:
                # root
                #  ╚══ dir1
                #      ╟── file1_1.txt
                #      ║
                #      ╚══ dir1_1

                $structure = [ordered]@{
                    "dir1" = [ordered]@{
                        "file1_1.txt" = $null
                        "dir1_1" = [ordered]@{
                        }
                    }
                }
                $root = New-FixtureTree -Structure $structure

                $items = $root | Select-TreeItem -Flatten

                $output = $items | Format-Tree -Mode Normal

                # Expected:
                #  ╚══ dir1
                #      ╟── file1_1.txt
                #      ║
                #      ╚══ dir1_1

                $output[0] | Should -Be "╚══ dir1"
                $output[1] | Should -Be "    ╟── file1_1.txt"
                $output[2] | Should -Be "    ║"
                $output[3] | Should -Be "    ╚══ dir1_1"

                # We expect 4 lines: dir1, file1_1.txt, a gap, and dir1_1.
                $output.Count | Should -Be 4
            }
        }

        It "Doesn't have a gap if there are only directories in subdirectories" {
            InModuleScope ShowTree {
                . (Join-Path $script:moduleSrcRoot "Tests\Fixtures\TreeItemFixtures.ps1")
                . (Join-Path $script:moduleSrcRoot "Tests\Helpers\PrivateHelpers.ps1")

                # Create a structure:
                # root
                #  ╚══ dir1
                #      ╠══ dir1_1
                #      ╚══ dir1_2

                $structure = [ordered]@{
                    "dir1" = [ordered]@{
                        "dir1_1" = [ordered]@{
                        }
                        "dir1_2" = [ordered]@{
                        }
                    }
                }
                $root = New-FixtureTree -Structure $structure

                $items = $root | Select-TreeItem -Flatten

                $output = $items | Format-Tree -Mode Normal

                # Expected:
                #  ╚══ dir1
                #      ╠══ dir1_1
                #      ╚══ dir1_2

                $output[0] | Should -Be "╚══ dir1"
                $output[1] | Should -Be "    ╠══ dir1_1"
                $output[2] | Should -Be "    ╚══ dir1_2"

                # We expect 3 lines: dir1, dir1_1, and dir1_2.
                $output.Count | Should -Be 3
            }
        }

        It "Has a gap between sibling directories if the 1st sibling has children" {
            InModuleScope ShowTree {
                . (Join-Path $script:moduleSrcRoot "Tests\Fixtures\TreeItemFixtures.ps1")
                . (Join-Path $script:moduleSrcRoot "Tests\Helpers\PrivateHelpers.ps1")

                # Create a structure:
                # root
                #  ╠══ dir1
                #  ║   ╙── file1_1.txt
                #  ║
                #  ╚══ dir2

                $structure = [ordered]@{
                    "dir1" = [ordered]@{
                        "file1_1.txt" = $null
                    }
                    "dir2" = [ordered]@{
                    }
                }
                $root = New-FixtureTree -Structure $structure

                $items = $root | Select-TreeItem -Flatten

                $output = $items | Format-Tree -Mode Normal

                # Expected:
                #  ╠══ dir1
                #  ║   ╙── file1_1.txt
                #  ║
                #  ╚══ dir2

                $output[0] | Should -Be "╠══ dir1"
                $output[1] | Should -Be "║   ╙── file1_1.txt"
                $output[2] | Should -Be "║"
                $output[3] | Should -Be "╚══ dir2"

                # We expect 4 lines: dir1, file1_1.txt, a gap, and dir2.
                $output.Count | Should -Be 4
            }
        }

        It "Has two gaps when there are two sibling directories and the 1st sibling has a mix of files and directories for children" {
            InModuleScope ShowTree {
                . (Join-Path $script:moduleSrcRoot "Tests\Fixtures\TreeItemFixtures.ps1")
                . (Join-Path $script:moduleSrcRoot "Tests\Helpers\PrivateHelpers.ps1")

                # Create a structure:
                # root
                #  ╠══ dir1
                #  ║   ╟── file1_1.txt
                #  ║   ║
                #  ║   ╚══ dir1_1
                #  ║
                #  ╚══ dir2

                $structure = [ordered]@{
                    "dir1" = [ordered]@{
                        "file1_1.txt" = $null
                        "dir1_1" = [ordered]@{
                        }
                    }
                    "dir2" = [ordered]@{
                    }
                }
                $root = New-FixtureTree -Structure $structure

                $items = $root | Select-TreeItem -Flatten

                $output = $items | Format-Tree -Mode Normal

                # Expected:
                #  ╠══ dir1
                #  ║   ╟── file1_1.txt
                #  ║   ║
                #  ║   ╚══ dir1_1
                #  ║
                #  ╚══ dir2

                $output[0] | Should -Be "╠══ dir1"
                $output[1] | Should -Be "║   ╟── file1_1.txt"
                $output[2] | Should -Be "║   ║"
                $output[3] | Should -Be "║   ╚══ dir1_1"
                $output[4] | Should -Be "║"
                $output[5] | Should -Be "╚══ dir2"

                # We expect 6 lines: dir1, file1_1.txt, a gap, dir1_1, a gap, and dir2.
                $output.Count | Should -Be 6
            }
        }

        It "Has a gap between the two sibling directories if the 1st sibling has directories for children" {
            InModuleScope ShowTree {
                . (Join-Path $script:moduleSrcRoot "Tests\Fixtures\TreeItemFixtures.ps1")
                . (Join-Path $script:moduleSrcRoot "Tests\Helpers\PrivateHelpers.ps1")

                # Create a structure:
                # root
                #  ╠══ dir1
                #  ║   ╚══ dir1_1
                #  ║
                #  ╚══ dir2

                $structure = [ordered]@{
                    "dir1" = [ordered]@{
                        "dir1_1" = [ordered]@{
                        }
                    }
                    "dir2" = [ordered]@{
                    }
                }
                $root = New-FixtureTree -Structure $structure

                $items = $root | Select-TreeItem -Flatten

                $output = $items | Format-Tree -Mode Normal

                # Expected:
                #  ╠══ dir1
                #  ║   ╚══ dir1_1
                #  ║
                #  ╚══ dir2

                $output[0] | Should -Be "╠══ dir1"
                $output[1] | Should -Be "║   ╚══ dir1_1"
                $output[2] | Should -Be "║"
                $output[3] | Should -Be "╚══ dir2"

                # We expect 4 lines: dir1, dir1_1, a gap, and dir2.
                $output.Count | Should -Be 4
            }
        }

        It "Doesn't have a gap between sibling directories if the 1st sibling has no children and the 2nd sibling has file children." {
            InModuleScope ShowTree {
                . (Join-Path $script:moduleSrcRoot "Tests\Fixtures\TreeItemFixtures.ps1")
                . (Join-Path $script:moduleSrcRoot "Tests\Helpers\PrivateHelpers.ps1")

                # Create a structure:
                # root
                #  ╠══ dir1
                #  ╚══ dir2
                #      ╙── file2_1.txt

                $structure = [ordered]@{
                    "dir1" = [ordered]@{
                    }
                    "dir2" = [ordered]@{
                        "file2_1.txt" = $null
                    }
                }
                $root = New-FixtureTree -Structure $structure

                $items = $root | Select-TreeItem -Flatten

                $output = $items | Format-Tree -Mode Normal

                # Expected:
                #  ╠══ dir1
                #  ╚══ dir2
                #      ╙── file2_1.txt

                $output[0] | Should -Be "╠══ dir1"
                $output[1] | Should -Be "╚══ dir2"
                $output[2] | Should -Be "    ╙── file2_1.txt"

                # We expect 3 lines: dir1, dir2, and file2_1.txt.
                $output.Count | Should -Be 3
            }
        }

        It "Has one gap if the 1st sibling has no children and the 2nd sibling has mixed children." {
            InModuleScope ShowTree {
                . (Join-Path $script:moduleSrcRoot "Tests\Fixtures\TreeItemFixtures.ps1")
                . (Join-Path $script:moduleSrcRoot "Tests\Helpers\PrivateHelpers.ps1")

                # Create a structure:
                # root
                #  ╠══ dir1
                #  ╚══ dir2
                #      ╟── file2_1.txt
                #      ║
                #      ╚══ dir2_1

                $structure = [ordered]@{
                    "dir1" = [ordered]@{
                    }
                    "dir2" = [ordered]@{
                        "file2_1.txt" = $null
                        "dir2_1" = [ordered]@{
                        }
                    }
                }
                $root = New-FixtureTree -Structure $structure

                $items = $root | Select-TreeItem -Flatten

                $output = $items | Format-Tree -Mode Normal

                # Expected:
                #  ╠══ dir1
                #  ╚══ dir2
                #      ╟── file2_1.txt
                #      ║
                #      ╚══ dir2_1

                $output[0] | Should -Be "╠══ dir1"
                $output[1] | Should -Be "╚══ dir2"
                $output[2] | Should -Be "    ╟── file2_1.txt"
                $output[3] | Should -Be "    ║"
                $output[4] | Should -Be "    ╚══ dir2_1"

                # We expect 5 lines: dir1, dir2, file2_1.txt, a gap, and dir2_1.
                $output.Count | Should -Be 5
            }
        }

        It "Doesn't have a gap between sibling directories if the 1st sibling has no children and the 2nd sibling has directory children." {
            InModuleScope ShowTree {
                . (Join-Path $script:moduleSrcRoot "Tests\Fixtures\TreeItemFixtures.ps1")
                . (Join-Path $script:moduleSrcRoot "Tests\Helpers\PrivateHelpers.ps1")

                # Create a structure:
                # root
                #  ╠══ dir1
                #  ╚══ dir2
                #      ╚══ dir2_1

                $structure = [ordered]@{
                    "dir1" = [ordered]@{
                    }
                    "dir2" = [ordered]@{
                        "dir2_1" = [ordered]@{
                        }
                    }
                }
                $root = New-FixtureTree -Structure $structure

                $items = $root | Select-TreeItem -Flatten

                $output = $items | Format-Tree -Mode Normal

                # Expected:
                #  ╠══ dir1
                #  ╚══ dir2
                #      ╚══ dir2_1

                $output[0] | Should -Be "╠══ dir1"
                $output[1] | Should -Be "╚══ dir2"
                $output[2] | Should -Be "    ╚══ dir2_1"

                # We expect 3 lines: dir1, dir2, and dir2_1.
                $output.Count | Should -Be 3
            }
        }
    }

    Context "Base structures (with files filtered out)" {
        It "Doesn't have a gap if there are only files in the root (filtered)" {
            InModuleScope ShowTree {
                . (Join-Path $script:moduleSrcRoot "Tests\Fixtures\TreeItemFixtures.ps1")
                . (Join-Path $script:moduleSrcRoot "Tests\Helpers\PrivateHelpers.ps1")

                # Create a structure:
                # root
                #  ╟── file1.txt (filtered)
                #  ╙── file2.txt (filtered)

                $structure = [ordered]@{
                    "file1.txt" = $null
                    "file2.txt" = $null
                }
                $root = New-FixtureTree -Structure $structure

                $items = $root | Select-TreeItem -Flatten -FilterScript { $_.Kind -ne 'File' }

                $output = $items | Format-Tree -Mode Normal

                # Expected:
                # $null # No output since all items are files and we filtered them out.

                # We expect 0 lines.
                $output.Count | Should -Be 0
            }
        }

        It "Doesn't have a gap if there are a mix of files and directories in the root (filtered)" {
            InModuleScope ShowTree {
                . (Join-Path $script:moduleSrcRoot "Tests\Fixtures\TreeItemFixtures.ps1")
                . (Join-Path $script:moduleSrcRoot "Tests\Helpers\PrivateHelpers.ps1")

                # Create a structure:
                # root
                #  ╟── file1.txt (filtered)
                #  ║
                #  ╚══ dir1

                $structure = [ordered]@{
                    "file1.txt" = $null
                    "dir1" = [ordered]@{
                    }
                }
                $root = New-FixtureTree -Structure $structure

                $items = $root | Select-TreeItem -Flatten -FilterScript { $_.Kind -ne 'File' }

                $output = @($items | Format-Tree -Mode Normal -Colorize:$false)

                # Expected:
                #  ╚══ dir1

                $output[0] | Should -Be "╚══ dir1"

                # We expect 1 line: dir1.
                $output.Count | Should -Be 1
            }
        }

        It "Doesn't have a gap if there are only files in subdirectories (filtered)" {
            InModuleScope ShowTree {
                . (Join-Path $script:moduleSrcRoot "Tests\Fixtures\TreeItemFixtures.ps1")
                . (Join-Path $script:moduleSrcRoot "Tests\Helpers\PrivateHelpers.ps1")

                # Create a structure:
                # root
                #  ╚══ dir1
                #      ╟── file1_1.txt (filtered)
                #      ╙── file1_2.txt (filtered)

                $structure = [ordered]@{
                    "dir1" = [ordered]@{
                        "file1_1.txt" = $null
                        "file1_2.txt" = $null
                    }
                }
                $root = New-FixtureTree -Structure $structure

                $items = $root | Select-TreeItem -Flatten -FilterScript { $_.Kind -ne 'File' }

                $output = @($items | Format-Tree -Mode Normal -Colorize:$false)

                # Expected:
                #  ╚══ dir1

                $output[0] | Should -Be "╚══ dir1"

                # We expect 1 line: dir1.
                $output.Count | Should -Be 1
            }
        }

        It "Doesn't have a gap between the mixed sibling files and directories in subdirectories (filtered)" {
            InModuleScope ShowTree {
                . (Join-Path $script:moduleSrcRoot "Tests\Fixtures\TreeItemFixtures.ps1")
                . (Join-Path $script:moduleSrcRoot "Tests\Helpers\PrivateHelpers.ps1")

                # Create a structure:
                # root
                #  ╚══ dir1
                #      ╟── file1_1.txt (filtered)
                #      ║
                #      ╚══ dir1_1

                $structure = [ordered]@{
                    "dir1" = [ordered]@{
                        "file1_1.txt" = $null
                        "dir1_1" = [ordered]@{
                        }
                    }
                }
                $root = New-FixtureTree -Structure $structure

                $items = $root | Select-TreeItem -Flatten -FilterScript { $_.Kind -ne 'File' }

                $output = $items | Format-Tree -Mode Normal

                # Expected:
                #  ╚══ dir1
                #      ╚══ dir1_1

                $output[0] | Should -Be "╚══ dir1"
                $output[1] | Should -Be "    ╚══ dir1_1"

                # We expect 2 lines: dir1 and dir1_1.
                $output.Count | Should -Be 2
            }
        }

        It "Doesn't have a gap between sibling directories if the 1st sibling has children (filtered)" {
            InModuleScope ShowTree {
                . (Join-Path $script:moduleSrcRoot "Tests\Fixtures\TreeItemFixtures.ps1")
                . (Join-Path $script:moduleSrcRoot "Tests\Helpers\PrivateHelpers.ps1")

                # Create a structure:
                # root
                #  ╠══ dir1
                #  ║   ╙── file1_1.txt (filtered)
                #  ║
                #  ╚══ dir2

                $structure = [ordered]@{
                    "dir1" = [ordered]@{
                        "file1_1.txt" = $null
                    }
                    "dir2" = [ordered]@{
                    }
                }
                $root = New-FixtureTree -Structure $structure

                $items = $root | Select-TreeItem -Flatten -FilterScript { $_.Kind -ne 'File' }

                $output = $items | Format-Tree -Mode Normal

                # Expected:
                #  ╠══ dir1
                #  ╚══ dir2

                $output[0] | Should -Be "╠══ dir1"
                $output[1] | Should -Be "╚══ dir2"

                # We expect 2 lines: dir1 and dir2.
                $output.Count | Should -Be 2
            }
        }

        It "Has one gap when there are two sibling directories and the 1st sibling has a mix of files and directories for children (filtered)" {
            InModuleScope ShowTree {
                . (Join-Path $script:moduleSrcRoot "Tests\Fixtures\TreeItemFixtures.ps1")
                . (Join-Path $script:moduleSrcRoot "Tests\Helpers\PrivateHelpers.ps1")

                # Create a structure:
                # root
                #  ╠══ dir1
                #  ║   ╟── file1_1.txt (filtered)
                #  ║   ║
                #  ║   ╚══ dir1_1
                #  ║
                #  ╚══ dir2

                $structure = [ordered]@{
                    "dir1" = [ordered]@{
                        "file1_1.txt" = $null
                        "dir1_1" = [ordered]@{
                        }
                    }
                    "dir2" = [ordered]@{
                    }
                }
                $root = New-FixtureTree -Structure $structure

                $items = $root | Select-TreeItem -Flatten -FilterScript { $_.Kind -ne 'File' }

                $output = $items | Format-Tree -Mode Normal

                # Expected:
                #  ╠══ dir1
                #  ║   ╚══ dir1_1
                #  ║
                #  ╚══ dir2

                $output[0] | Should -Be "╠══ dir1"
                $output[1] | Should -Be "║   ╚══ dir1_1"
                $output[2] | Should -Be "║"
                $output[3] | Should -Be "╚══ dir2"

                # We expect 4 lines: dir1, dir1_1, a gap, and dir2.
                $output.Count | Should -Be 4
            }
        }

        It "Doesn't have a gap between sibling directories if the 1st sibling has no children and the 2nd sibling has file children.  (filtered)" {
            InModuleScope ShowTree {
                . (Join-Path $script:moduleSrcRoot "Tests\Fixtures\TreeItemFixtures.ps1")
                . (Join-Path $script:moduleSrcRoot "Tests\Helpers\PrivateHelpers.ps1")

                # Create a structure:
                # root
                #  ╠══ dir1
                #  ╚══ dir2
                #      ╙── file2_1.txt (filtered)

                $structure = [ordered]@{
                    "dir1" = [ordered]@{
                    }
                    "dir2" = [ordered]@{
                        "file2_1.txt" = $null
                    }
                }
                $root = New-FixtureTree -Structure $structure

                $items = $root | Select-TreeItem -Flatten -FilterScript { $_.Kind -ne 'File' }

                $output = $items | Format-Tree -Mode Normal

                # Expected:
                #  ╠══ dir1
                #  ╚══ dir2

                $output[0] | Should -Be "╠══ dir1"
                $output[1] | Should -Be "╚══ dir2"

                # We expect 2 lines: dir1 and dir2.
                $output.Count | Should -Be 2
            }
        }

        It "Doesn't have a gap if the 1st sibling has no children and the 2nd sibling has mixed children. (filtered)" {
            InModuleScope ShowTree {
                . (Join-Path $script:moduleSrcRoot "Tests\Fixtures\TreeItemFixtures.ps1")
                . (Join-Path $script:moduleSrcRoot "Tests\Helpers\PrivateHelpers.ps1")

                # Create a structure:
                # root
                #  ╠══ dir1
                #  ╚══ dir2
                #      ╟── file2_1.txt (filtered)
                #      ║
                #      ╚══ dir2_1

                $structure = [ordered]@{
                    "dir1" = [ordered]@{
                    }
                    "dir2" = [ordered]@{
                        "file2_1.txt" = $null
                        "dir2_1" = [ordered]@{
                        }
                    }
                }
                $root = New-FixtureTree -Structure $structure

                $items = $root | Select-TreeItem -Flatten -FilterScript { $_.Kind -ne 'File' }

                $output = $items | Format-Tree -Mode Normal

                # Expected:
                #  ╠══ dir1
                #  ╚══ dir2
                #      ╚══ dir2_1

                $output[0] | Should -Be "╠══ dir1"
                $output[1] | Should -Be "╚══ dir2"
                $output[2] | Should -Be "    ╚══ dir2_1"

                # We expect 3 lines: dir1, dir2, and dir2_1.
                $output.Count | Should -Be 3
            }
        }
    }
}
