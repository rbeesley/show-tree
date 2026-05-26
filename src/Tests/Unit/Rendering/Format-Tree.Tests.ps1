# src\Tests\Unit\Rendering\Format-Tree.Tests.ps1

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

Describe "Format-Tree" {
    Context "Basic Rendering" {
        It "Renders a single file" {
            InModuleScope ShowTree -Parameters @{ FixtureScripts = $script:FixtureScripts } {
                param( [string[]] $FixtureScripts ); foreach ($script in $FixtureScripts) { . $script }

                $structure = [ordered]@{
                    "File1.txt" = $null
                }

                $root = New-FixtureTree -Structure $structure
                $items = $root | Select-TreeItem -Expand Descendants
                $out = @($items | Format-Tree -Mode 'Normal')

                # # Write-Host "[DEBUG_LOG] Output lines:"
                # $out | ForEach-Object { Write-Host "[DEBUG_LOG] '$_'" }
                
                $out.Count | Should -Be 1
                $out[0] | Should -Be "╙── File1.txt"
            }
        }


        It "Renders a directory with a file" {
            InModuleScope ShowTree -Parameters @{ FixtureScripts = $script:FixtureScripts } {
                param( [string[]] $FixtureScripts ); foreach ($script in $FixtureScripts) { . $script }

                $structure = [ordered]@{
                    "Dir1" = [ordered]@{
                        "File1.txt" = $null
                    }
                }

                $root = New-FixtureTree -Structure $structure
                $items = $root | Select-TreeItem -Expand Descendants
                $out = @($items | Format-Tree -Mode 'Normal')

                $out.Count | Should -Be 2
                $out[0] | Should -Be "╚══ Dir1"
                $out[1] | Should -Be "    ╙── File1.txt"
            }
        }

        It "Renders multiple levels" {
            InModuleScope ShowTree -Parameters @{ FixtureScripts = $script:FixtureScripts } {
                param( [string[]] $FixtureScripts ); foreach ($script in $FixtureScripts) { . $script }

                $structure = [ordered]@{
                    "RootDir" = [ordered]@{
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
                $out[0] | Should -Be "╚══ RootDir"
                $out[1] | Should -Be "    ╚══ SubDir"
                $out[2] | Should -Be "        ╙── File1.txt"
            }
        }

        It "Renders a simple nested graph correctly" {
            InModuleScope ShowTree -Parameters @{ FixtureScripts = $script:FixtureScripts } {
                param( [string[]] $FixtureScripts ); foreach ($script in $FixtureScripts) { . $script }

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
                $items = $root | Select-TreeItem -Expand Descendants
                $out = @($items | Format-Tree -Mode 'Normal')

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

                for ($i = 0; $i -lt [Math]::Max($out.Count, $expected.Count); $i++) {
                    $expectedLine = $expected[$i]
                    $out[$i] | Should -Be $expectedLine -ErrorAction Continue
                }

                $out.Count | Should -Be $expected.Count
            }
        }
    }


    Context "Modes and Styles" {
       It "Renders in Tree.com mode" {
            InModuleScope ShowTree -Parameters @{ FixtureScripts = $script:FixtureScripts } {
                param( [string[]] $FixtureScripts ); foreach ($script in $FixtureScripts) { . $script }

                $structure = [ordered]@{
                    "File1.txt" = $null
                }

                $root = New-FixtureTree -Structure $structure
                $items = $root | Select-TreeItem -Expand Descendants
                $out = @($items | Format-Tree -Mode 'Tree')

                $out[0] | Should -Be "    File1.txt"
            }
        }

       It "Renders directory in Tree.com mode" {
            InModuleScope ShowTree -Parameters @{ FixtureScripts = $script:FixtureScripts } {
                param( [string[]] $FixtureScripts ); foreach ($script in $FixtureScripts) { . $script }

               $structure = [ordered]@{
                   "Dir" = [ordered]@{
                       "File.txt" = $null
                       "SubDir" = [ordered]@{ }
                   }
               }

               $root = New-FixtureTree -Structure $structure
               $items = $root | Select-TreeItem -Expand Descendants
               $out = @($items | Format-Tree -Mode 'Tree' -NoGap)

               $out[0] | Should -Be "└───Dir"
               $out[1] | Should -Be "    │   File.txt"
               $out[2] | Should -Be "    └───SubDir"
           }
       }

        It "Renders in ASCII mode" {
            InModuleScope ShowTree -Parameters @{ FixtureScripts = $script:FixtureScripts } {
                param( [string[]] $FixtureScripts ); foreach ($script in $FixtureScripts) { . $script }

                $structure = [ordered]@{
                    "File1.txt" = $null
                }

                $root = New-FixtureTree -Structure $structure
                $items = $root | Select-TreeItem -Expand Descendants
                $out = @($items | Format-Tree -Mode 'Normal' -Ascii)

                $out[0] | Should -Be "\-- File1.txt"
            }
        }

        It "Renders in List mode" {
            InModuleScope ShowTree -Parameters @{ FixtureScripts = $script:FixtureScripts } {
                param( [string[]] $FixtureScripts ); foreach ($script in $FixtureScripts) { . $script }

                $structure = [ordered]@{
                    "File1.txt" = $null
                }

                $root = New-FixtureTree -Structure $structure
                $items = $root | Select-TreeItem -Expand Descendants
                $out = @($items | Format-Tree -Mode 'List')

                $out[0] | Should -Be " File1.txt"
            }
        }
    }

    Context "Links" {
        It "Renders symlink targets when requested" {
            InModuleScope ShowTree -Parameters @{ FixtureScripts = $script:FixtureScripts } {
                param( [string[]] $FixtureScripts ); foreach ($script in $FixtureScripts) { . $script }

                $item = New-FixtureTreeItem -Name "Link" -IsSymlink $true -Target "C:\Target"
                $out = @($item | Format-Tree -ShowTargets)

                $out[0] | Should -Be "╙── Link -> C:\Target"
            }
        }
    }

    Context "Style Profile Path Handling" {
        It "Accepts a file path for StyleProfile" {
            InModuleScope ShowTree -Parameters @{ FixtureScripts = $script:FixtureScripts } {
                param( [string[]] $FixtureScripts ); foreach ($script in $FixtureScripts) { . $script }

                $styleProfilePath = Join-Path $script:moduleSrcRoot "Data\DefaultStyleProfile.psd1"
                $item = New-FixtureTreeItem -Name "File.txt"
                $out = @($item | Format-Tree -StyleProfile $styleProfilePath)

                $out[0] | Should -Be "╙── File.txt"
            }
        }
    }

    Context "Streaming and Graphs" {
        It "Correctly handles a stream of items where some are children of others" {
            InModuleScope ShowTree -Parameters @{ FixtureScripts = $script:FixtureScripts } {
                param( [string[]] $FixtureScripts ); foreach ($script in $FixtureScripts) { . $script }

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


        It "Correctly handles multiple root items" {
            InModuleScope ShowTree -Parameters @{ FixtureScripts = $script:FixtureScripts } {
                param( [string[]] $FixtureScripts ); foreach ($script in $FixtureScripts) { . $script }

                $item1 = New-FixtureTreeItem -Name "File1.txt"
                $item2 = New-FixtureTreeItem -Name "File2.txt"

                $out = @($item1, $item2 | Format-Tree -Mode 'Normal')

                $out.Count | Should -Be 2
                $out[0] | Should -Be "╟── File1.txt"
                $out[1] | Should -Be "╙── File2.txt"
            }
        }

       It "Renders a cousin gap between major root groups in Normal mode" {
            InModuleScope ShowTree -Parameters @{ FixtureScripts = $script:FixtureScripts } {
                param( [string[]] $FixtureScripts ); foreach ($script in $FixtureScripts) { . $script }
               
                # Root structure:
                # Directories
                #   SubDir
                # Files
                #   File.txt

                $structure = [ordered]@{
                     "Directories" = [ordered]@{
                          "SubDir" = [ordered]@{ }
                     }
                     "Files" = [ordered]@{
                          "File.txt" = $null
                     }
                }

                $root = New-FixtureTree -Structure $structure

                $items = $root | Select-TreeItem -Expand Descendants
                $out = @($items | Format-Tree -Mode 'Normal')

                # Expected output (Unicode):
                # ╠══ Directories
                # ║   ╚══ SubDir
                # ║
                # ╚══ Files
                #     ╙── File.txt

                $out.Count | Should -Be 5
                $out[0] | Should -Be "╠══ Directories"
                $out[1] | Should -Be "║   ╚══ SubDir"
                $out[2] | Should -Be "║"
                $out[3] | Should -Be "╚══ Files"
                $out[4] | Should -Be "    ╙── File.txt"
           }
       }

        It "Does not render a gap when children are filtered out (DirectoryOnly scenario)" {
            InModuleScope ShowTree -Parameters @{ FixtureScripts = $script:FixtureScripts } {
                param( [string[]] $FixtureScripts ); foreach ($script in $FixtureScripts) { . $script }

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

       It "Renders a gap between files and directories at the same level" {
           InModuleScope ShowTree {
               . (Join-Path $script:moduleSrcRoot "Tests\Fixtures\TreeItemFixtures.ps1")
               
               # Structure:
               # Root
               #   File1.txt
               #   Dir1
               #     File2.txt

                $structure = [ordered]@{
                    "Root" = [ordered]@{
                        "File1.txt" = $null
                        "Dir1" = [ordered]@{
                            "File2.txt" = $null
                        }
                    }
                }

                $root = New-FixtureTree -Structure $structure

                $items = $root | Select-TreeItem -Expand Descendants
                $out = @($items | Format-Tree -Mode 'Normal')

               # Expected lines:
               # ╚══ Root
               #     ╟── File1.txt
               #     ║
               #     ╚══ Dir1
               #         ╙── File2.txt

               $out[0] | Should -Be "╚══ Root"
               $out[1] | Should -Be "    ╟── File1.txt"
               $out[2] | Should -Be "    ║"
               $out[3] | Should -Be "    ╚══ Dir1"
               $out[4] | Should -Be "        ╙── File2.txt"
           }
       }
    }
}
