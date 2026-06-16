# src/Tests/Unit/Rendering/Format-Tree.Tests.ps1

BeforeAll {
    $script:TestRoot = Resolve-Path "$PSScriptRoot\..\.."
    $script:ModuleUnderTest = . "$script:TestRoot\Helpers\Import-ModuleUnderTest.ps1" `
        -StartPath $PSScriptRoot `
        -ModuleName 'ShowTree' `
        -SourceRootName 'src' `
        -Exclude 'src/Tests/*' `
        -PassThru

    $script:FixtureScripts = @(
        "$script:TestRoot\Helpers\PrivateHelpers.ps1"
        "$script:TestRoot\Fixtures\TreeItemFixtures.ps1"
    )

    $script:comprehensiveStructure = [ordered]@{
        'hidden-file.tmp' = @{'FileAttributes' = 'Hidden'}
        'system-file.sys' = @{'FileAttributes' = 'System'}
        '<gap-2>' = $null
        'dir-1' = [ordered]@{
            'file-1-1.txt' = $null
            'file-1-2.txt' = $null
            '<gap-6>' = $null
            'dir-1-1' = [ordered]@{
                'file-1-1-1.txt' = $null
            }
        }
        '<gap-9>' = $null
        'link-dir' = @{'Target' = 'C:\Elsewhere'; 'IsContainer' = $true; 'IsSymlink' = $true; 'Children' = [ordered]@{ }}
        'dir-2' = [ordered]@{
            'file-2-1.txt' = $null
        }
    }
}

Describe 'Format-Tree' {
    Context 'Basic Rendering' {

        It 'renders Item records in stream order' {
            InModuleScope ShowTree -Parameters @{ FixtureScripts = $script:FixtureScripts } {
                param([string[]] $FixtureScripts)
                foreach ($script in $FixtureScripts) { . $script }

                $structure = [ordered]@{
                    'file-a.txt' = $null
                    'dir-a' = [ordered]@{}
                }

                $records = New-FixtureTreeRecordStream -Structure $structure
                $output = @($records | Format-Tree)

                $output.Count | Should -Be 2
                $output[0] | Should -Match 'file-a\.txt'
                $output[1] | Should -Match 'dir-a'
            }
        }

        It 'renders Gap records as additional output lines' {
            InModuleScope ShowTree -Parameters @{ FixtureScripts = $script:FixtureScripts } {
                param([string[]] $FixtureScripts)
                foreach ($script in $FixtureScripts) { . $script }

                $structure = [ordered]@{
                    'dir-a' = [ordered]@{
                        'inside-a.txt' = $null
                    }
                    '<gap-2>' = $null
                    'dir-b' = [ordered]@{}
                }

                $records = New-FixtureTreeRecordStream -Structure $structure
                $output = @($records | Format-Tree)

                $output.Count | Should -Be 4
                $output[0] | Should -Match 'dir-a'
                $output[1] | Should -Match 'inside-a\.txt'
                $output[2] | Should -Not -Match 'dir-a|inside-a\.txt|dir-b'
                $output[3] | Should -Match 'dir-b'
            }
        }

        It 'renders a single file'{
            InModuleScope ShowTree -Parameters @{ FixtureScripts = $script:FixtureScripts } {
                param([string[]] $FixtureScripts)
                foreach ($script in $FixtureScripts) { . $script }

                $structure = [ordered]@{
                    'file-a.txt' = $null
                }

                $records = New-FixtureTreeRecordStream -Structure $structure
                $output = @($records | Format-Tree)

                $output.Count | Should -Be 1
                $output[0] | Should -Match 'file-a\.txt'
            }
        }

        It 'renders a directory with a file' {
            InModuleScope ShowTree -Parameters @{ FixtureScripts = $script:FixtureScripts } {
                param([string[]] $FixtureScripts)
                foreach ($script in $FixtureScripts) { . $script }

                $structure = [ordered]@{
                    'dir-a' = [ordered]@{
                        'file-a.txt' = $null
                    }
                }

                $records = New-FixtureTreeRecordStream -Structure $structure
                $output = @($records | Format-Tree)

                $output.Count | Should -Be 2
                $output[0] | Should -Match 'dir-a'
                $output[1] | Should -Match 'file-a\.txt'
            }
        }

        It 'renders multiple levels' {
            InModuleScope ShowTree -Parameters @{ FixtureScripts = $script:FixtureScripts } {
                param([string[]] $FixtureScripts)
                foreach ($script in $FixtureScripts) { . $script }

                $structure = [ordered]@{
                    "RootDir" = [ordered]@{
                        "SubDir" = [ordered]@{
                            "File1.txt" = $null
                        }
                    }
                }

                $records = New-FixtureTreeRecordStream -Structure $structure
                $output = @($records | Format-Tree)

                $output.Count | Should -Be 3
                $output[0] | Should -Match 'RootDir'
                $output[1] | Should -Match 'SubDir'
                $output[2] | Should -Match 'File1\.txt'
            }
        }

        It 'renders multiple top-level items with a gap in between' {
            InModuleScope ShowTree -Parameters @{ FixtureScripts = $script:FixtureScripts } {
                param([string[]] $FixtureScripts)
                foreach ($script in $FixtureScripts) { . $script }

                $structure = [ordered]@{
                    "file-a.txt" = $null
                    "<gap-1>" = $null
                    "dir-a" = [ordered]@{}
                }

                $records = New-FixtureTreeRecordStream -Structure $structure
                $output = @($records | Format-Tree)

                $output.Count | Should -Be 3
                $output[0] | Should -Match 'file-a\.txt'
                $output[2] | Should -Match 'dir-a'
            }
        }

        It 'renders a simple nested graph correctly' {
            InModuleScope ShowTree -Parameters @{ FixtureScripts = $script:FixtureScripts } {
                param([string[]] $FixtureScripts)
                foreach ($script in $FixtureScripts) { . $script }

                $structure = [ordered]@{
                    "dir-a" = [ordered]@{
                        "file-a.txt" = $null
                    }
                    "<gap-2>" = $null
                    "dir-b" = [ordered]@{
                        "file-b.txt" = $null
                    }
                    "<gap-5>" = $null
                    "file-root.txt" = $null
                }

                # Generate records directly from the structure
                $records = New-FixtureTreeRecordStream -Structure $structure
                $output = @($records | Format-Tree)

                $output.Count | Should -Be 7
                $output[0] | Should -Match 'dir-a'
                $output[1] | Should -Match 'file-a\.txt'
                $output[3] | Should -Match 'dir-b'
                $output[4] | Should -Match 'file-b\.txt'
                $output[6] | Should -Match 'file-root\.txt'
            }
        }
    }

    Context 'Modes and styles' {
        Context 'Normal mode' {
            It 'renders a simple tree correctly in ASCII style' {
                InModuleScope ShowTree -Parameters @{ FixtureScripts = $script:FixtureScripts } {
                    param([string[]] $FixtureScripts)
                    foreach ($script in $FixtureScripts) { . $script }

                    $structure = [ordered]@{
                        'dir1' = [ordered]@{}
                        'dir2' = [ordered]@{}
                    }

                    # Generate records directly from the structure
                    $records = New-FixtureTreeRecordStream -Structure $structure
                    $output = @($records | Format-Tree -Mode Normal -Ascii)

                    $expected = @(
                        '+== dir1'
                        '\== dir2'
                    )

                    $output | Should -Be $expected
                }
            }

            It 'renders a simple tree correctly in Unicode style' {
                InModuleScope ShowTree -Parameters @{ FixtureScripts = $script:FixtureScripts } {
                    param([string[]] $FixtureScripts)
                    foreach ($script in $FixtureScripts) { . $script }

                    $structure = [ordered]@{
                        'dir1' = [ordered]@{}
                        'dir2' = [ordered]@{}
                    }

                    # Generate records directly from the structure
                    $records = New-FixtureTreeRecordStream -Structure $structure
                    $output = @($records | Format-Tree -Mode Normal)

                    $expected = @(
                        '╠══ dir1'
                        '╚══ dir2'
                    )

                    $output | Should -Be $expected
                }
            }

            It 'renders a complex tree structure correctly with ASCII style' {
                InModuleScope ShowTree -Parameters @{
                        FixtureScripts = $script:FixtureScripts
                        ComprehensiveStructure = $script:comprehensiveStructure
                } {
                    param([string[]] $FixtureScripts)
                    foreach ($script in $FixtureScripts) { . $script }

                    # Use the comprehensive structure defined in BeforeAll
                    $records = New-FixtureTreeRecordStream -Structure $ComprehensiveStructure
                    $output = @($records | Format-Tree -Mode Normal -ShowTargets -Ascii)

                    # Expected output (manually verified against the structure):
                    $expected = @(
                        '+-- hidden-file.tmp'
                        '+-- system-file.sys'
                        '|'
                        '+== dir-1'
                        '|   +-- file-1-1.txt'
                        '|   +-- file-1-2.txt'
                        '|   |'
                        '|   \== dir-1-1'
                        '|       \-- file-1-1-1.txt'
                        '|'
                        '+== link-dir -> C:\Elsewhere'
                        '\== dir-2'
                        '    \-- file-2-1.txt'
                    )

                    $output | Should -Be $expected
                }
            }

            It 'renders a complex tree structure correctly with Unicode style' {
                InModuleScope ShowTree -Parameters @{
                        FixtureScripts = $script:FixtureScripts
                        ComprehensiveStructure = $script:comprehensiveStructure
                } {
                    param([string[]] $FixtureScripts)
                    foreach ($script in $FixtureScripts) { . $script }

                    # Use the comprehensive structure defined in BeforeAll
                    $records = New-FixtureTreeRecordStream -Structure $ComprehensiveStructure
                    $output = @($records | Format-Tree -Mode Normal -ShowTargets)

                    # Expected output (manually verified against the structure):
                    $expected = @(
                        '╟── hidden-file.tmp'
                        '╟── system-file.sys'
                        '║'
                        '╠══ dir-1'
                        '║   ╟── file-1-1.txt'
                        '║   ╟── file-1-2.txt'
                        '║   ║'
                        '║   ╚══ dir-1-1'
                        '║       ╙── file-1-1-1.txt'
                        '║'
                        '╠══ link-dir -> C:\Elsewhere'
                        '╚══ dir-2'
                        '    ╙── file-2-1.txt'
                    )

                    $output | Should -Be $expected
                }
            }
        }

        Context 'Tree mode' {
            It 'renders a simple tree correctly in ASCII style' {
                InModuleScope ShowTree -Parameters @{ FixtureScripts = $script:FixtureScripts } {
                    param([string[]] $FixtureScripts)
                    foreach ($script in $FixtureScripts) { . $script }

                    $structure = [ordered]@{
                        'dir1' = [ordered]@{}
                        'dir2' = [ordered]@{}
                    }

                    # Generate records directly from the structure
                    $records = New-FixtureTreeRecordStream -Structure $structure
                    $output = @($records | Format-Tree -Mode Tree -Ascii)

                    # Expected output:
                    $expected = @(
                        '+---dir1'
                        '\---dir2'
                    )

                    $output | Should -Be $expected
                }
            }

            It 'renders a simple tree mode correctly in Unicode style' {
                InModuleScope ShowTree -Parameters @{ FixtureScripts = $script:FixtureScripts } {
                    param([string[]] $FixtureScripts)
                    foreach ($script in $FixtureScripts) { . $script }

                    $structure = [ordered]@{
                        'dir1' = [ordered]@{}
                        'dir2' = [ordered]@{}
                    }

                    # Generate records directly from the structure
                    $records = New-FixtureTreeRecordStream -Structure $structure
                    $output = @($records | Format-Tree -Mode Tree)

                    # Expected output:
                    $expected = @(
                        '├───dir1'
                        '└───dir2'
                    )

                    $output | Should -Be $expected
                }
            }

            It 'renders a complex tree structure correctly in Tree mode with ASCII style' {
                InModuleScope ShowTree -Parameters @{
                        FixtureScripts = $script:FixtureScripts
                        ComprehensiveStructure = $script:comprehensiveStructure
                } {
                    param([string[]] $FixtureScripts)
                    foreach ($script in $FixtureScripts) { . $script }

                    # Use the comprehensive structure defined in BeforeAll
                    $records = New-FixtureTreeRecordStream -Structure $ComprehensiveStructure
                    $output = @($records | Format-Tree -Mode Tree -Ascii)

                    # Expected output (manually verified against the structure):
                    $expected = @(
                        '|   hidden-file.tmp'
                        '|   system-file.sys'
                        '|'
                        '+---dir-1'
                        '|   |   file-1-1.txt'
                        '|   |   file-1-2.txt'
                        '|   |'
                        '|   \---dir-1-1'
                        '|           file-1-1-1.txt'
                        '|'
                        '+---link-dir'
                        '\---dir-2'
                        '        file-2-1.txt'
                    )

                    $output | Should -Be $expected
                }
            }

            It 'renders a complex tree structure correctly in Tree mode with Unicode style' {
                InModuleScope ShowTree -Parameters @{
                        FixtureScripts = $script:FixtureScripts
                        ComprehensiveStructure = $script:comprehensiveStructure
                } {
                    param([string[]] $FixtureScripts)
                    foreach ($script in $FixtureScripts) { . $script }

                    # Use the comprehensive structure defined in BeforeAll
                    $records = New-FixtureTreeRecordStream -Structure $ComprehensiveStructure
                    $output = @($records | Format-Tree -Mode Tree)

                    # Expected output (manually verified against the structure):
                    $expected = @(
                        '│   hidden-file.tmp'
                        '│   system-file.sys'
                        '│'
                        '├───dir-1'
                        '│   │   file-1-1.txt'
                        '│   │   file-1-2.txt'
                        '│   │'
                        '│   └───dir-1-1'
                        '│           file-1-1-1.txt'
                        '│'
                        '├───link-dir'
                        '└───dir-2'
                        '        file-2-1.txt'
                    )

                    $output | Should -Be $expected
                }
            }
        }

        Context 'List mode' {
            It 'renders a simple tree correctly in ASCII style' {
                InModuleScope ShowTree -Parameters @{ FixtureScripts = $script:FixtureScripts } {
                    param([string[]] $FixtureScripts)
                    foreach ($script in $FixtureScripts) { . $script }

                    $structure = [ordered]@{
                        'dir1' = [ordered]@{}
                        'dir2' = [ordered]@{}
                    }

                    # Generate records directly from the structure
                    $records = New-FixtureTreeRecordStream -Structure $structure
                    $output = @($records | Format-Tree -Mode List -NoGap -Ascii)

                    $expected = @(
                        ' dir1'
                        ' dir2'
                    )

                    $output | Should -Be $expected
                }
            }

            It 'renders a simple tree correctly in Unicode style' {
                InModuleScope ShowTree -Parameters @{ FixtureScripts = $script:FixtureScripts } {
                    param([string[]] $FixtureScripts)
                    foreach ($script in $FixtureScripts) { . $script }

                    $structure = [ordered]@{
                        'dir1' = [ordered]@{}
                        'dir2' = [ordered]@{}
                    }

                    # Generate records directly from the structure
                    $records = New-FixtureTreeRecordStream -Structure $structure
                    $output = @($records | Format-Tree -Mode List -NoGap)

                    $expected = @(
                        ' dir1'
                        ' dir2'
                    )

                    $output | Should -Be $expected
                }
            }

            It 'renders a complex tree structure correctly with ASCII style' {
                InModuleScope ShowTree -Parameters @{
                        FixtureScripts = $script:FixtureScripts
                        ComprehensiveStructure = $script:comprehensiveStructure
                } {
                    param([string[]] $FixtureScripts)
                    foreach ($script in $FixtureScripts) { . $script }

                    # Use the comprehensive structure defined in BeforeAll
                    $records = New-FixtureTreeRecordStream -Structure $ComprehensiveStructure
                    $output = @($records | Format-Tree -Mode List -NoGap -Ascii)

                    # Expected output (manually verified against the structure):
                    $expected = @(
                        ' hidden-file.tmp'
                        ' system-file.sys'
                        ' dir-1'
                        '  file-1-1.txt'
                        '  file-1-2.txt'
                        '  dir-1-1'
                        '   file-1-1-1.txt'
                        ' link-dir'
                        ' dir-2'
                        '  file-2-1.txt'
                    )

                    $output | Should -Be $expected
                }
            }

            It 'renders a complex tree structure correctly with Unicode style' {
                InModuleScope ShowTree -Parameters @{
                        FixtureScripts = $script:FixtureScripts
                        ComprehensiveStructure = $script:comprehensiveStructure
                } {
                    param([string[]] $FixtureScripts)
                    foreach ($script in $FixtureScripts) { . $script }

                    # Use the comprehensive structure defined in BeforeAll
                    $records = New-FixtureTreeRecordStream -Structure $ComprehensiveStructure
                    $output = @($records | Format-Tree -Mode List -NoGap)

                    # Expected output (manually verified against the structure):
                    $expected = @(
                        ' hidden-file.tmp'
                        ' system-file.sys'
                        ' dir-1'
                        '  file-1-1.txt'
                        '  file-1-2.txt'
                        '  dir-1-1'
                        '   file-1-1-1.txt'
                        ' link-dir'
                        ' dir-2'
                        '  file-2-1.txt'
                    )

                    $output | Should -Be $expected
                }
            }
        }
    }

    Context 'Option Handling' {
        It 'suppresses Gap records when NoGap is specified' {
            InModuleScope ShowTree -Parameters @{ FixtureScripts = $script:FixtureScripts } {
                param([string[]] $FixtureScripts)
                foreach ($script in $FixtureScripts) { . $script }

                $rootPath = if ($IsWindows) { 'C:\Root' } else { '/root' }

                $records = @(
                    New-FixtureTreeRecord `
                        -Name 'file-a' `
                        -ParentPath $rootPath `
                        -IsLastSibling:$false `
                        -HasLaterSiblingDirectory:$true `
                        -Metadata @{ IsContainer = $true }

                    New-FixtureTreeRecord `
                        -RecordType Gap `
                        -Depth 1 `
                        -AncestorIsLastSibling @($false)

                    New-FixtureTreeRecord `
                        -Name 'dir-a' `
                        -ParentPath $rootPath `
                        -IsLastSibling:$true `
                        -Metadata @{ IsContainer = $true }
                )

                $output = @($records | Format-Tree -Mode Normal -Ascii -NoGap)

                $output.Count | Should -Be 2
                $output[0] | Should -Match 'file-a'
                $output[1] | Should -Match 'dir-a'
            }
        }

        It 'renders link targets when ShowTargets is specified' {
            InModuleScope ShowTree -Parameters @{ FixtureScripts = $script:FixtureScripts } {
                param([string[]] $FixtureScripts)
                foreach ($script in $FixtureScripts) { . $script }

                $rootPath = if ($IsWindows) { 'C:\Root' } else { '/root' }

                $targetPath = Join-Path $rootPath 'target.txt'
                $records = @(
                    New-FixtureTreeRecord `
                        -Name 'link.txt' `
                        -ParentPath $rootPath `
                        -Metadata @{
                            IsSymlink = $true
                            Target = $targetPath
                        }
                )

                $output = @($records | Format-Tree -Mode Normal -Ascii -ShowTargets -NoGap)

                $escapedSourcePath = [regex]::Escape('link.txt')
                $escapedTargetPath = [regex]::Escape($targetPath)

                $output.Count | Should -Be 1
                $output[0] | Should -Match $escapedSourcePath
                $output[0] | Should -Match $escapedTargetPath
            }
        }

        It 'accepts a file path for StyleProfile' {
            InModuleScope ShowTree -Parameters @{
                    FixtureScripts = $script:FixtureScripts
                    ComprehensiveStructure = $script:comprehensiveStructure
            } { 
                param([string[]] $FixtureScripts)
                foreach ($script in $FixtureScripts) { . $script }

                $styleProfilePath = Join-Path $script:moduleSrcRoot "Data\DefaultStyleProfile.psd1"

                # Use the comprehensive structure defined in BeforeAll
                $records = New-FixtureTreeRecordStream -Structure $ComprehensiveStructure
                $output = @($records | Format-Tree -Mode Normal -StyleProfile $styleProfilePath)

                $output.Count | Should -Be 13
            }
        }
    }

    Context 'Error Handling' {
        It 'throws for non TreeRecord input' {
            InModuleScope ShowTree {
                {
                    [PSCustomObject]@{
                        Name = 'not-a-record'
                    } | Format-Tree -Mode Normal -Ascii
                } | Should -Throw
            }
        }

        It 'throws when an Item record is missing TreeLayout metadata' {
            InModuleScope ShowTree -Parameters @{ FixtureScripts = $script:FixtureScripts } {
                param([string[]] $FixtureScripts)
                foreach ($script in $FixtureScripts) { . $script }

                $rootPath = if ($IsWindows) { 'C:\Root' } else { '/root' }

                $item = New-FixtureTreeItem `
                    -Name 'file-a.txt' `
                    -ParentPath $rootPath `
                    -Depth 0

                $record = [PSCustomObject]@{
                    PSTypeName  = 'ShowTree.TreeRecord'
                    RecordType  = 'Item'
                    TreeItem    = $item
                    TreeLayout  = $null
                }

                {
                    $record | Format-Tree -Mode Normal -Ascii
                } | Should -Throw
            }
        }

        It 'throws when a Gap record is missing TreeLayout metadata' {
            InModuleScope ShowTree {
                $record = [PSCustomObject]@{
                    PSTypeName = 'ShowTree.TreeRecord'
                    RecordType = 'Gap'
                    TreeItem   = $null
                    TreeLayout = $null
                }

                {
                    $record | Format-Tree -Mode Normal -Ascii
                } | Should -Throw
            }
        }
    }
}
