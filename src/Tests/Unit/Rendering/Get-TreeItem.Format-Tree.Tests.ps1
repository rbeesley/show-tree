# src/Tests/Unit/Rendering/Get-TreeItem.Format-Tree.Tests.ps1

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
}

Describe 'Get-TreeItem | Format-Tree' {
    It 'renders streamed TreeRecord output' {
        InModuleScope ShowTree -Parameters @{ FixtureScripts = $script:FixtureScripts } {
            param([string[]] $FixtureScripts)
            foreach ($script in $FixtureScripts) { . $script }

            $rootPath = $IsWindows ? 'C:\Root' : '/root'

            $provider = [PSCustomObject]@{
                PSTypeName   = 'ShowTree.TreeChildProvider'
                Name         = 'Test'
                ProviderMode = 'PowerShell'
                GetChildren  = {
                    param([string] $Path, [int] $Depth)

                    [PSCustomObject]@{
                        Files = @(
                            New-FixtureTreeItem `
                                -Name 'file-a.txt' `
                                -ParentPath $Path `
                                -Depth $Depth
                        )
                        Directories = @(
                            New-FixtureTreeItem `
                                -Name 'dir-a' `
                                -ParentPath $Path `
                                -Metadata @{ IsContainer = $true } `
                                -Depth $Depth
                        )
                    }
                }
            }

            Mock Resolve-Path {
                [PSCustomObject]@{
                    ProviderPath = $rootPath
                    Path         = $rootPath
                }
            }

            Mock New-TreeChildProvider {
                $provider
            }

            $output = @(
            Get-TreeItem -Path $rootPath -Depth 0 |
                    Format-Tree -Mode Normal -Ascii -NoGap
            )

            $output.Count | Should -Be 2
            $output[0] | Should -Match 'file-a\.txt'
            $output[1] | Should -Match 'dir-a'
        }
    }

    It 'renders gap records from traversal' {
        InModuleScope ShowTree -Parameters @{ FixtureScripts = $script:FixtureScripts } {
            param([string[]] $FixtureScripts)
            foreach ($script in $FixtureScripts) { . $script }

            $rootPath = $IsWindows ? 'C:\Root' : '/root'
            $dirAPath = Join-Path $rootPath 'dir-a'

            $provider = [PSCustomObject]@{
                PSTypeName   = 'ShowTree.TreeChildProvider'
                Name         = 'Test'
                ProviderMode = 'PowerShell'
                GetChildren  = {
                    param([string] $Path, [int] $Depth)

                    if ($Path -eq $rootPath) {
                        return [PSCustomObject]@{
                            Files = @()
                            Directories = @(
                                New-FixtureTreeItem `
                                    -Name 'dir-a' `
                                    -ParentPath $Path `
                                    -Metadata @{ IsContainer = $true } `
                                    -Depth $Depth

                                New-FixtureTreeItem `
                                    -Name 'dir-b' `
                                    -ParentPath $Path `
                                    -Metadata @{ IsContainer = $true } `
                                    -Depth $Depth
                            )
                        }
                    }

                    if ($Path -eq $dirAPath) {
                        return [PSCustomObject]@{
                            Files = @(
                                New-FixtureTreeItem `
                                    -Name 'inside-a.txt' `
                                    -ParentPath $Path `
                                    -Depth $Depth
                            )
                            Directories = @()
                        }
                    }

                    [PSCustomObject]@{
                        Files       = @()
                        Directories = @()
                    }
                }
            }

            Mock Resolve-Path {
                [PSCustomObject]@{
                    ProviderPath = $rootPath
                    Path         = $rootPath
                }
            }

            Mock New-TreeChildProvider {
                $provider
            }

            $output = @(
                Get-TreeItem -Path $rootPath -Depth 2 |
                    Format-Tree -Mode Normal -Ascii
            )

            $output.Count | Should -Be 4
            $output[0] | Should -Match 'dir-a'
            $output[1] | Should -Match 'inside-a\.txt'
            $output[2] | Should -Not -Match 'dir-a|inside-a\.txt|dir-b'
            $output[3] | Should -Match 'dir-b'
        }
    }
}
