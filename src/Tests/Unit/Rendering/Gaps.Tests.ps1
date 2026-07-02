# src/Tests/Unit/Rendering/Gaps.Tests.ps1

BeforeAll {
    $script:TestRoot = Resolve-Path "$PSScriptRoot\..\.."
    $script:ModuleUnderTest = . "$script:TestRoot\Helpers\Import-ModuleUnderTest.ps1" `
        -StartPath $PSScriptRoot `
        -ModuleName 'ShowTree' `
        -SourceRootName 'src' `
        -Exclude 'src/Tests/*' `
        -PassThru
    $script:FixtureScripts  = @(
        "$script:TestRoot\Fixtures\TreeItemFixtures.ps1"
        "$script:TestRoot\Helpers\PrivateHelpers.ps1"
    )
}

Describe "Gaps generation" {
    Context "Invoke-TreeTraversal emits Gap records in the expected scenarios" {
        It "Doesn't have a gap with an empty root" {
            InModuleScope ShowTree -Parameters @{ FixtureScripts = $script:FixtureScripts } {
                param( [string[]] $FixtureScripts ); foreach ($script in $FixtureScripts) { . $script }

                # Create a structure:
                # Root (empty)

                $structure = [ordered]@{
                }

                $tree = New-FixtureTree -Structure $structure
                $provider = New-FixtureTreeChildProvider -Root $tree
                $records = @(
                    Invoke-TreeTraversal -Path $provider.RootPath -Provider $provider
                )

                # Expected:
                # $null # No output since the root is empty.

                $records | Should -HaveCount 0
            }
        }

        It "Doesn't have a gap if there is only one file in the root" {
            InModuleScope ShowTree -Parameters @{ FixtureScripts = $script:FixtureScripts } {
                param( [string[]] $FixtureScripts ); foreach ($script in $FixtureScripts) { . $script }

                # Create a structure:
                #  ╙── file1.txt

                $structure = [ordered]@{
                    "file1.txt" = $null
                }

                $tree = New-FixtureTree -Structure $structure
                $provider = New-FixtureTreeChildProvider -Root $tree
                $records = @(
                    Invoke-TreeTraversal -Path $provider.RootPath -Provider $provider
                )

                # Expected:
                #  ╙── file1.txt

                $records | Should -HaveCount 1
                $records.RecordType | Should -Be 'Item'
                $records.RecordType | Should -Not -Be 'Gap'

#                $output = @($records | Format-Tree -Mode Normal -Colorize:$false)
#
#                $output[0] | Should -Be "╙── file1.txt"
#
#                # We expect 1 line: file1.txt.
#                $output.Count | Should -Be 1
            }
        }

        It "Doesn't have a gap if there is only one directory in the root" {
            InModuleScope ShowTree -Parameters @{ FixtureScripts = $script:FixtureScripts } {
                param( [string[]] $FixtureScripts ); foreach ($script in $FixtureScripts) { . $script }

                # Create a structure:
                #  ╚══ dir1

                $structure = [ordered]@{
                    "dir1" = [ordered]@{
                    }
                }

                $tree = New-FixtureTree -Structure $structure
                $provider = New-FixtureTreeChildProvider -Root $tree
                $records = @(
                    Invoke-TreeTraversal -Path $provider.RootPath -Provider $provider
                )

                # Expected:
                #  ╚══ dir1

                $records | Should -HaveCount 1
                $records.RecordType | Should -Be 'Item'
                $records.RecordType | Should -Not -Be 'Gap'
            }
        }

        It "Doesn't have a gap if there are only files in the root" {
            InModuleScope ShowTree -Parameters @{ FixtureScripts = $script:FixtureScripts } {
                param( [string[]] $FixtureScripts ); foreach ($script in $FixtureScripts) { . $script }

                # Create a structure:
                #  ╟── file1.txt
                #  ╙── file2.txt

                $structure = [ordered]@{
                    "file1.txt" = $null
                    "file2.txt" = $null
                }

                $tree = New-FixtureTree -Structure $structure
                $provider = New-FixtureTreeChildProvider -Root $tree
                $records = @(
                    Invoke-TreeTraversal -Path $provider.RootPath -Provider $provider
                )

                # Expected:
                #  ╟── file1.txt
                #  ╙── file2.txt

                $records | Should -HaveCount 2
                $records.RecordType | Should -Be @(
                    'Item',
                    'Item'
                )
                ($records | Where-Object RecordType -eq 'Item').TreeItem.Name | Should -Be @(
                    'file1.txt'
                    'file2.txt'
                )
            }
        }

        It "Has a gap if there are a mix of files and directories in the root" {
            InModuleScope ShowTree -Parameters @{ FixtureScripts = $script:FixtureScripts } {
                param( [string[]] $FixtureScripts ); foreach ($script in $FixtureScripts) { . $script }

                # Create a structure:
                #  ╟── file1.txt
                #  ╚══ dir1

                $structure = [ordered]@{
                    "file1.txt" = $null
                    "dir1" = [ordered]@{
                    }
                }

                $tree = New-FixtureTree -Structure $structure
                $provider = New-FixtureTreeChildProvider -Root $tree
                $records = @(
                    Invoke-TreeTraversal -Path $provider.RootPath -Provider $provider
                )

                # Expected:
                #  ╟── file1.txt
                #  ║
                #  ╚══ dir1

                $records | Should -HaveCount 3
                $records.RecordType | Should -Be @(
                    'Item'
                    'Gap'
                    'Item'
                )
                ($records | Where-Object RecordType -eq 'Item').TreeItem.Name | Should -Be @(
                    'file1.txt'
                    'dir1'
                )
            }
        }

        It "Doesn't have a gap between sibling directories if the 1st sibling has no children" {
            InModuleScope ShowTree -Parameters @{ FixtureScripts = $script:FixtureScripts } {
                param( [string[]] $FixtureScripts ); foreach ($script in $FixtureScripts) { . $script }

                # Create a structure:
                #  ╠══ dir1
                #  ╚══ dir2

                $structure = [ordered]@{
                    "dir1" = [ordered]@{
                    }
                    "dir2" = [ordered]@{
                    }
                }

                $tree = New-FixtureTree -Structure $structure
                $provider = New-FixtureTreeChildProvider -Root $tree
                $records = @(
                    Invoke-TreeTraversal -Path $provider.RootPath -Provider $provider
                )

                # Expected:
                #  ╠══ dir1
                #  ╚══ dir2

                $records.Count | Should -Be 2
                $records.RecordType | Should -Be @(
                    'Item'
                    'Item'
                )
                ($records | Where-Object RecordType -eq 'Item').TreeItem.Name | Should -Be @(
                    'dir1'
                    'dir2'
                )
            }
        }

        It "Doesn't have a gap between the parent and child directories if the parent has no children" {
            InModuleScope ShowTree -Parameters @{ FixtureScripts = $script:FixtureScripts } {
                param( [string[]] $FixtureScripts ); foreach ($script in $FixtureScripts) { . $script }

                # Create a structure:
                #  ╚══ dir1
                #      ╚══ dir1_1

                $structure = [ordered]@{
                    "dir1" = [ordered]@{
                        "dir1_1" = [ordered]@{
                        }
                    }
                }

                $tree = New-FixtureTree -Structure $structure
                $provider = New-FixtureTreeChildProvider -Root $tree
                $records = @(
                    Invoke-TreeTraversal -Path $provider.RootPath -Provider $provider
                )

                # Expected:
                #  ╚══ dir1
                #      ╚══ dir1_1

                $records.Count | Should -Be 2
                $records.RecordType | Should -Be @(
                    'Item'
                    'Item'
                )
                ($records | Where-Object RecordType -eq 'Item').TreeItem.Name | Should -Be @(
                    'dir1'
                    'dir1_1'
                )
            }
        }

        It "Doesn't have a gap if there are only files in subdirectories" {
            InModuleScope ShowTree -Parameters @{ FixtureScripts = $script:FixtureScripts } {
                param( [string[]] $FixtureScripts ); foreach ($script in $FixtureScripts) { . $script }

                # Create a structure:
                #  ╚══ dir1
                #      ╟── file1_1.txt
                #      ╙── file1_2.txt

                $structure = [ordered]@{
                    "dir1" = [ordered]@{
                        "file1_1.txt" = $null
                        "file1_2.txt" = $null
                    }
                }

                $tree = New-FixtureTree -Structure $structure
                $provider = New-FixtureTreeChildProvider -Root $tree
                $records = @(
                    Invoke-TreeTraversal -Path $provider.RootPath -Provider $provider
                )

                # Expected:
                #  ╚══ dir1
                #      ╟── file1_1.txt
                #      ╙── file1_2.txt

                $records.Count | Should -Be 3
                $records.RecordType | Should -Be @(
                    'Item'
                    'Item'
                    'Item'
                )
                ($records | Where-Object RecordType -eq 'Item').TreeItem.Name | Should -Be @(
                    'dir1'
                    'file1_1.txt'
                    'file1_2.txt'
                )
            }
        }

        It "Has a gap between the mixed sibling files and directories in subdirectories" {
            InModuleScope ShowTree -Parameters @{ FixtureScripts = $script:FixtureScripts } {
                param( [string[]] $FixtureScripts ); foreach ($script in $FixtureScripts) { . $script }

                # Create a structure:
                #  ╚══ dir1
                #      ╟── file1_1.txt
                #      ╚══ dir1_1

                $structure = [ordered]@{
                    "dir1" = [ordered]@{
                        "file1_1.txt" = $null
                        "dir1_1" = [ordered]@{
                        }
                    }
                }

                $tree = New-FixtureTree -Structure $structure
                $provider = New-FixtureTreeChildProvider -Root $tree
                $records = @(
                    Invoke-TreeTraversal -Path $provider.RootPath -Provider $provider
                )

                # Expected:
                #  ╚══ dir1
                #      ╟── file1_1.txt
                #      ║
                #      ╚══ dir1_1

                $records.Count | Should -Be 4
                $records.RecordType | Should -Be @(
                    'Item'
                    'Item'
                    'Gap'
                    'Item'
                )
                ($records | Where-Object RecordType -eq 'Item').TreeItem.Name | Should -Be @(
                    'dir1'
                    'file1_1.txt'
                    'dir1_1'
                )
            }
        }

        It "Doesn't have a gap if there are only directories in subdirectories" {
            InModuleScope ShowTree -Parameters @{ FixtureScripts = $script:FixtureScripts } {
                param( [string[]] $FixtureScripts ); foreach ($script in $FixtureScripts) { . $script }

                # Create a structure:
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

                $tree = New-FixtureTree -Structure $structure
                $provider = New-FixtureTreeChildProvider -Root $tree
                $records = @(
                    Invoke-TreeTraversal -Path $provider.RootPath -Provider $provider
                )

                # Expected:
                #  ╚══ dir1
                #      ╠══ dir1_1
                #      ╚══ dir1_2

                $records.Count | Should -Be 3
                $records.RecordType | Should -Be @(
                    'Item'
                    'Item'
                    'Item'
                )
                ($records | Where-Object RecordType -eq 'Item').TreeItem.Name | Should -Be @(
                    'dir1'
                    'dir1_1'
                    'dir1_2'
                )
            }
        }

        It "Has a gap between sibling directories if the 1st sibling has children" {
            InModuleScope ShowTree -Parameters @{ FixtureScripts = $script:FixtureScripts } {
                param( [string[]] $FixtureScripts ); foreach ($script in $FixtureScripts) { . $script }

                # Create a structure:
                #  ╠══ dir1
                #  ║   ╙── file1_1.txt
                #  ╚══ dir2

                $structure = [ordered]@{
                    "dir1" = [ordered]@{
                        "file1_1.txt" = $null
                    }
                    "dir2" = [ordered]@{
                    }
                }

                $tree = New-FixtureTree -Structure $structure
                $provider = New-FixtureTreeChildProvider -Root $tree
                $records = @(
                    Invoke-TreeTraversal -Path $provider.RootPath -Provider $provider
                )

                # Expected:
                #  ╠══ dir1
                #  ║   ╙── file1_1.txt
                #  ║
                #  ╚══ dir2

                $records.Count | Should -Be 4
                $records.RecordType | Should -Be @(
                    'Item'
                    'Item'
                    'Gap'
                    'Item'
                )
                ($records | Where-Object RecordType -eq 'Item').TreeItem.Name | Should -Be @(
                    'dir1'
                    'file1_1.txt'
                    'dir2'
                )
            }
        }

        It "Has two gaps when there are two sibling directories and the 1st sibling has a mix of files and directories for children" {
            InModuleScope ShowTree -Parameters @{ FixtureScripts = $script:FixtureScripts } {
                param( [string[]] $FixtureScripts ); foreach ($script in $FixtureScripts) { . $script }

                # Create a structure:
                #  ╠══ dir1
                #  ║   ╟── file1_1.txt
                #  ║   ╚══ dir1_1
                #  ╚══ dir2

                $structure = [ordered]@{
                    "dir1" = [ordered]@{
                        "file1_1.txt" = $null
                        "dir1_1" = [ordered]@{}
                    }
                    "dir2" = [ordered]@{}
                }

                $tree = New-FixtureTree -Structure $structure
                $provider = New-FixtureTreeChildProvider -Root $tree
                $records = @(
                    Invoke-TreeTraversal -Path $provider.RootPath -Provider $provider
                )

                # Expected:
                #  ╠══ dir1
                #  ║   ╟── file1_1.txt
                #  ║   ║
                #  ║   ╚══ dir1_1
                #  ║
                #  ╚══ dir2

                $records.Count | Should -Be 6
                $records.RecordType | Should -Be @(
                    'Item'
                    'Item'
                    'Gap'
                    'Item'
                    'Gap'
                    'Item'
                )

                ($records | Where-Object RecordType -eq 'Item').TreeItem.Name | Should -Be @(
                    'dir1'
                    'file1_1.txt'
                    'dir1_1'
                    'dir2'
                )

                # $firstGap = $records[2]
                # $firstGap.TreeItem | Should -BeNullOrEmpty
                # $firstGap.TreeLayout.Depth | Should -Be 1
                # $firstGap.TreeLayout.RelativeDepth | Should -Be 1
                # $firstGap.TreeLayout.AncestorIsLastSibling | Should -Be @($false)

                # $secondGap = $records[4]
                # $secondGap.TreeItem | Should -BeNullOrEmpty
                # $secondGap.TreeLayout.Depth | Should -Be 0
                # $secondGap.TreeLayout.RelativeDepth | Should -Be 0
                # $secondGap.TreeLayout.AncestorIsLastSibling | Should -Be @()

                # $output = $records | Format-Tree -Mode Normal -Colorize:$false

                # $output | Should -Be @(
                #     "╠══ dir1"
                #     "║   ╟── file1_1.txt"
                #     "║   ║"
                #     "║   ╚══ dir1_1"
                #     "║"
                #     "╚══ dir2"
                # )
            }
        }

        It "Has a gap between the two sibling directories if the 1st sibling has directories for children" {
            InModuleScope ShowTree -Parameters @{ FixtureScripts = $script:FixtureScripts } {
                param( [string[]] $FixtureScripts ); foreach ($script in $FixtureScripts) { . $script }

                # Create a structure:
                #  ╠══ dir1
                #  ║   ╚══ dir1_1
                #  ╚══ dir2

                $structure = [ordered]@{
                    "dir1" = [ordered]@{
                        "dir1_1" = [ordered]@{
                        }
                    }
                    "dir2" = [ordered]@{
                    }
                }

                $tree = New-FixtureTree -Structure $structure
                $provider = New-FixtureTreeChildProvider -Root $tree
                $records = @(
                    Invoke-TreeTraversal -Path $provider.RootPath -Provider $provider
                )

                # Expected:
                #  ╠══ dir1
                #  ║   ╚══ dir1_1
                #  ║
                #  ╚══ dir2

                $records.Count | Should -Be 4
                $records.RecordType | Should -Be @(
                    'Item'
                    'Item'
                    'Gap'
                    'Item'
                )
                ($records | Where-Object RecordType -eq 'Item').TreeItem.Name | Should -Be @(
                    'dir1'
                    'dir1_1'
                    'dir2'
                )
            }
        }

        It "Doesn't have a gap between sibling directories if the 1st sibling has no children and the 2nd sibling has file children." {
            InModuleScope ShowTree -Parameters @{ FixtureScripts = $script:FixtureScripts } {
                param( [string[]] $FixtureScripts ); foreach ($script in $FixtureScripts) { . $script }

                # Create a structure:
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

                $tree = New-FixtureTree -Structure $structure
                $provider = New-FixtureTreeChildProvider -Root $tree
                $records = @(
                    Invoke-TreeTraversal -Path $provider.RootPath -Provider $provider
                )

                # Expected:
                #  ╠══ dir1
                #  ╚══ dir2
                #      ╙── file2_1.txt

                $records.Count | Should -Be 3
                $records.RecordType | Should -Be @(
                    'Item'
                    'Item'
                    'Item'
                )
                ($records | Where-Object RecordType -eq 'Item').TreeItem.Name | Should -Be @(
                    'dir1'
                    'dir2'
                    'file2_1.txt'
                )
            }
        }

        It "Has one gap if the 1st sibling has no children and the 2nd sibling has mixed children." {
            InModuleScope ShowTree -Parameters @{ FixtureScripts = $script:FixtureScripts } {
                param( [string[]] $FixtureScripts ); foreach ($script in $FixtureScripts) { . $script }

                # Create a structure:
                #  ╠══ dir1
                #  ╚══ dir2
                #      ╟── file2_1.txt
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

                $tree = New-FixtureTree -Structure $structure
                $provider = New-FixtureTreeChildProvider -Root $tree
                $records = @(
                    Invoke-TreeTraversal -Path $provider.RootPath -Provider $provider
                )

                # Expected:
                #  ╠══ dir1
                #  ╚══ dir2
                #      ╟── file2_1.txt
                #      ║
                #      ╚══ dir2_1

                $records.Count | Should -Be 5
                $records.RecordType | Should -Be @(
                    'Item'
                    'Item'
                    'Item'
                    'Gap'
                    'Item'
                )
                ($records | Where-Object RecordType -eq 'Item').TreeItem.Name | Should -Be @(
                    'dir1'
                    'dir2'
                    'file2_1.txt'
                    'dir2_1'
                )
            }
        }

        It "Doesn't have a gap between sibling directories if the 1st sibling has no children and the 2nd sibling has directory children." {
            InModuleScope ShowTree -Parameters @{ FixtureScripts = $script:FixtureScripts } {
                param( [string[]] $FixtureScripts ); foreach ($script in $FixtureScripts) { . $script }

                # Create a structure:
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

                $tree = New-FixtureTree -Structure $structure
                $provider = New-FixtureTreeChildProvider -Root $tree
                $records = @(
                    Invoke-TreeTraversal -Path $provider.RootPath -Provider $provider
                )

                # Expected:
                #  ╠══ dir1
                #  ╚══ dir2
                #      ╚══ dir2_1

                $records.Count | Should -Be 3
                $records.RecordType | Should -Be @(
                    'Item'
                    'Item'
                    'Item'
                )
                ($records | Where-Object RecordType -eq 'Item').TreeItem.Name | Should -Be @(
                    'dir1'
                    'dir2'
                    'dir2_1'
                )
            }
        }
    }

    Context "Base structures (with files filtered out)" {
        It "Doesn't have a gap if there are only files in the root (filtered)" {
            InModuleScope ShowTree -Parameters @{ FixtureScripts = $script:FixtureScripts } {
                param( [string[]] $FixtureScripts ); foreach ($script in $FixtureScripts) { . $script }

                # Create a structure:
                #  ╟── file1.txt (filtered)
                #  ╙── file2.txt (filtered)

                $structure = [ordered]@{
                    "file1.txt" = $null
                    "file2.txt" = $null
                }

                $tree = New-FixtureTree -Structure $structure
                $provider = New-FixtureTreeChildProvider -Root $tree
                $records = @(
                    Invoke-TreeTraversal -Path $provider.RootPath -Provider $provider -DirectoryOnly
                )

                # Expected:
                # $null # No output since all items are files and we filtered them out.

                $records.Count | Should -Be 0
            }
        }

        It "Doesn't have a gap if there are a mix of files and directories in the root (filtered)" {
            InModuleScope ShowTree -Parameters @{ FixtureScripts = $script:FixtureScripts } {
                param( [string[]] $FixtureScripts ); foreach ($script in $FixtureScripts) { . $script }

                # Create a structure:
                #  ╟── file1.txt (filtered)
                #  ╚══ dir1

                $structure = [ordered]@{
                    "file1.txt" = $null
                    "dir1" = [ordered]@{
                    }
                }

                $tree = New-FixtureTree -Structure $structure
                $provider = New-FixtureTreeChildProvider -Root $tree
                $records = @(
                    Invoke-TreeTraversal -Path $provider.RootPath -Provider $provider -DirectoryOnly
                )

                # Expected:
                #  ╚══ dir1

                $records.Count | Should -Be 1
                $records.RecordType | Should -Be 'Item'
                ($records | Where-Object RecordType -eq 'Item').TreeItem.Name | Should -Be "dir1"
            }
        }

        It "Doesn't have a gap if there are only files in subdirectories (filtered)" {
            InModuleScope ShowTree -Parameters @{ FixtureScripts = $script:FixtureScripts } {
                param( [string[]] $FixtureScripts ); foreach ($script in $FixtureScripts) { . $script }

                # Create a structure:
                #  ╚══ dir1
                #      ╟── file1_1.txt (filtered)
                #      ╙── file1_2.txt (filtered)

                $structure = [ordered]@{
                    "dir1" = [ordered]@{
                        "file1_1.txt" = $null
                        "file1_2.txt" = $null
                    }
                }

                $tree = New-FixtureTree -Structure $structure
                $provider = New-FixtureTreeChildProvider -Root $tree
                $records = @(
                    Invoke-TreeTraversal -Path $provider.RootPath -Provider $provider -DirectoryOnly
                )

                # Expected:
                #  ╚══ dir1

                $records.Count | Should -Be 1
                $records.RecordType | Should -Be 'Item'
                ($records | Where-Object RecordType -eq 'Item').TreeItem.Name | Should -Be "dir1"
            }
        }

        It "Doesn't have a gap between the mixed sibling files and directories in subdirectories (filtered)" {
            InModuleScope ShowTree -Parameters @{ FixtureScripts = $script:FixtureScripts } {
                param( [string[]] $FixtureScripts ); foreach ($script in $FixtureScripts) { . $script }

                # Create a structure:
                #  ╚══ dir1
                #      ╟── file1_1.txt (filtered)
                #      ╚══ dir1_1

                $structure = [ordered]@{
                    "dir1" = [ordered]@{
                        "file1_1.txt" = $null
                        "dir1_1" = [ordered]@{
                        }
                    }
                }

                $tree = New-FixtureTree -Structure $structure
                $provider = New-FixtureTreeChildProvider -Root $tree
                $records = @(
                    Invoke-TreeTraversal -Path $provider.RootPath -Provider $provider -DirectoryOnly
                )

                # Expected:
                #  ╚══ dir1
                #      ╚══ dir1_1

                $records.Count | Should -Be 2
                $records.RecordType | Should -Be @(
                    'Item'
                    'Item'
                )
                ($records | Where-Object RecordType -eq 'Item').TreeItem.Name | Should -Be @(
                    'dir1'
                    'dir1_1'
                )
            }
        }

        It "Doesn't have a gap between sibling directories if the 1st sibling has children (filtered)" {
            InModuleScope ShowTree -Parameters @{ FixtureScripts = $script:FixtureScripts } {
                param( [string[]] $FixtureScripts ); foreach ($script in $FixtureScripts) { . $script }

                # Create a structure:
                #  ╠══ dir1
                #  ║   ╙── file1_1.txt (filtered)
                #  ╚══ dir2

                $structure = [ordered]@{
                    "dir1" = [ordered]@{
                        "file1_1.txt" = $null
                    }
                    "dir2" = [ordered]@{
                    }
                }

                $tree = New-FixtureTree -Structure $structure
                $provider = New-FixtureTreeChildProvider -Root $tree
                $records = @(
                    Invoke-TreeTraversal -Path $provider.RootPath -Provider $provider -DirectoryOnly
                )
                
                # Expected:
                #  ╠══ dir1
                #  ╚══ dir2

                $records.Count | Should -Be 2
                $records.RecordType | Should -Be @(
                    'Item'
                    'Item'
                )
                ($records | Where-Object RecordType -eq 'Item').TreeItem.Name | Should -Be @(
                    'dir1'
                    'dir2'
                )
            }
        }

        It "Has one gap when there are two sibling directories and the 1st sibling has a mix of files and directories for children (filtered)" {
            InModuleScope ShowTree -Parameters @{ FixtureScripts = $script:FixtureScripts } {
                param( [string[]] $FixtureScripts ); foreach ($script in $FixtureScripts) { . $script }

                # Create a structure:
                #  ╠══ dir1
                #  ║   ╟── file1_1.txt (filtered)
                #  ║   ╚══ dir1_1
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

                $tree = New-FixtureTree -Structure $structure
                $provider = New-FixtureTreeChildProvider -Root $tree
                $records = @(
                    Invoke-TreeTraversal -Path $provider.RootPath -Provider $provider -DirectoryOnly
                )

                # Expected:
                #  ╠══ dir1
                #  ║   ╚══ dir1_1
                #  ║
                #  ╚══ dir2

                $records.Count | Should -Be 4
                $records.RecordType | Should -Be @(
                    'Item'
                    'Item'
                    'Gap'
                    'Item'
                )
                ($records | Where-Object RecordType -eq 'Item').TreeItem.Name | Should -Be @(
                    'dir1'
                    'dir1_1'
                    'dir2'
                )
            }
        }

        It "Doesn't have a gap between sibling directories if the 1st sibling has no children and the 2nd sibling has file children.  (filtered)" {
            InModuleScope ShowTree -Parameters @{ FixtureScripts = $script:FixtureScripts } {
                param( [string[]] $FixtureScripts ); foreach ($script in $FixtureScripts) { . $script }

                # Create a structure:
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

                $tree = New-FixtureTree -Structure $structure
                $provider = New-FixtureTreeChildProvider -Root $tree
                $records = @(
                    Invoke-TreeTraversal -Path $provider.RootPath -Provider $provider -DirectoryOnly
                )

                # Expected:
                #  ╠══ dir1
                #  ╚══ dir2

                $records.Count | Should -Be 2
                $records.RecordType | Should -Be @(
                    'Item'
                    'Item'
                )
                ($records | Where-Object RecordType -eq 'Item').TreeItem.Name | Should -Be @(
                    'dir1'
                    'dir2'
                )
            }
        }

        It "Doesn't have a gap if the 1st sibling has no children and the 2nd sibling has mixed children. (filtered)" {
            InModuleScope ShowTree -Parameters @{ FixtureScripts = $script:FixtureScripts } {
                param( [string[]] $FixtureScripts ); foreach ($script in $FixtureScripts) { . $script }

                # Create a structure:
                #  ╠══ dir1
                #  ╚══ dir2
                #      ╟── file2_1.txt (filtered)
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

                $tree = New-FixtureTree -Structure $structure
                $provider = New-FixtureTreeChildProvider -Root $tree
                $records = @(
                    Invoke-TreeTraversal -Path $provider.RootPath -Provider $provider -DirectoryOnly
                )

                # Expected:
                #  ╠══ dir1
                #  ╚══ dir2
                #      ╚══ dir2_1

                $records.Count | Should -Be 3
                $records.RecordType | Should -Be @(
                    'Item'
                    'Item'
                    'Item'
                )
                ($records | Where-Object RecordType -eq 'Item').TreeItem.Name | Should -Be @(
                    'dir1'
                    'dir2'
                    'dir2_1'
                )
            }
        }
    }
}
