# src/Tests/Unit/Enumeration/Get-ImmediateTreeChild.Tests.ps1

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

Describe 'Get-ImmediateTreeChild' {
    Context 'PowerShell provider mode' {
        It 'converts immediate Get-ChildItem results into ShowTree.TreeItem objects' {
            InModuleScope ShowTree -Parameters @{ FixtureScripts = $script:FixtureScripts } {
                param([string[]] $FixtureScripts)
                foreach ($script in $FixtureScripts) { . $script }

                $rootPath = if ($IsWindows) { 'C:\Root' } else { '/root' }

                $rawChildren = @(
                    New-TestProviderItem `
                        -Name 'b.txt' `
                        -ParentPath $rootPath `
                        -Length 20

                    New-TestProviderItem `
                        -Name 'dir-a' `
                        -ParentPath $rootPath `
                        -IsDirectory
                )

                Mock Resolve-Path { $null }
                Mock Test-Path { $true }
                Mock Get-ChildItem { $rawChildren }

                $provider = New-TreeChildProvider -ProviderMode PowerShell

                $items = @(Get-ImmediateTreeChild `
                    -Path $rootPath `
                    -RootPath $rootPath `
                    -Depth 2 `
                    -Provider $provider)

                $items.Count | Should -Be 2
                $items[0].PSTypeNames | Should -Contain 'ShowTree.TreeItem'
                $items[1].PSTypeNames | Should -Contain 'ShowTree.TreeItem'

                $items.Name | Should -Contain 'b.txt'
                $items.Name | Should -Contain 'dir-a'

                ($items | Where-Object Name -eq 'b.txt').Kind | Should -Be 'File'
                ($items | Where-Object Name -eq 'dir-a').Kind | Should -Be 'Directory'

                foreach ($item in $items) {
                    $item.Depth | Should -Be 2
                    $item.ParentPath | Should -Be $rootPath
                }

                Should -Invoke Get-ChildItem -Times 1 -Exactly -ParameterFilter {
                    $LiteralPath -eq $rootPath -and
                            $Force -eq $true
                }
            }
        }

        It 'enumerates only the mocked immediate child group and does not recurse' {
            InModuleScope ShowTree -Parameters @{ FixtureScripts = $script:FixtureScripts } {
                param([string[]] $FixtureScripts)
                foreach ($script in $FixtureScripts) { . $script }

                $rootPath = if ($IsWindows) { 'C:\Root' } else { '/root' }

                $rawChildren = @(
                    New-TestProviderItem `
                        -Name 'dir-a' `
                        -ParentPath $rootPath `
                        -IsDirectory
                )

                Mock Resolve-Path { $null }
                Mock Test-Path { $true }
                Mock Get-ChildItem { $rawChildren }

                $provider = New-TreeChildProvider -ProviderMode PowerShell

                $items = @(Get-ImmediateTreeChild `
                    -Path $rootPath `
                    -RootPath $rootPath `
                    -Depth 0 `
                    -Provider $provider)

                $items.Name | Should -Be @('dir-a')
                $items.Name | Should -Not -Contain 'nested.txt'

                Should -Invoke Get-ChildItem -Times 1 -Exactly
            }
        }

        It 'orders files before directories and then by name' {
            InModuleScope ShowTree -Parameters @{ FixtureScripts = $script:FixtureScripts } {
                param([string[]] $FixtureScripts)
                foreach ($script in $FixtureScripts) { . $script }

                $rootPath = if ($IsWindows) { 'C:\Root' } else { '/root' }

                $rawChildren = @(
                    New-TestProviderItem `
                        -Name 'dir-b' `
                        -ParentPath $rootPath `
                        -IsDirectory

                    New-TestProviderItem `
                        -Name 'b.txt' `
                        -ParentPath $rootPath `
                        -Length 20

                    New-TestProviderItem `
                        -Name 'dir-a' `
                        -ParentPath $rootPath `
                        -IsDirectory

                    New-TestProviderItem `
                        -Name 'a.txt' `
                        -ParentPath $rootPath `
                        -Length 10
                )

                Mock Resolve-Path { $null }
                Mock Test-Path { $true }
                Mock Get-ChildItem { $rawChildren }

                $provider = New-TreeChildProvider -ProviderMode PowerShell

                $items = @(Get-ImmediateTreeChild `
                    -Path $rootPath `
                    -RootPath $rootPath `
                    -Depth 0 `
                    -Provider $provider)

                $items.Name | Should -Be @(
                    'a.txt'
                    'b.txt'
                    'dir-a'
                    'dir-b'
                )
            }
        }

        It 'filters by exact exclude name' {
            InModuleScope ShowTree -Parameters @{ FixtureScripts = $script:FixtureScripts } {
                param([string[]] $FixtureScripts)
                foreach ($script in $FixtureScripts) { . $script }

                $rootPath = if ($IsWindows) { 'C:\Root' } else { '/root' }

                $rawChildren = @(
                    New-TestProviderItem `
                        -Name 'a.txt' `
                        -ParentPath $rootPath `
                        -Length 10

                    New-TestProviderItem `
                        -Name 'dir-a' `
                        -ParentPath $rootPath `
                        -IsDirectory
                )

                Mock Resolve-Path { $null }
                Mock Test-Path { $true }
                Mock Get-ChildItem { $rawChildren }

                $provider = New-TreeChildProvider -ProviderMode PowerShell

                $items = @(Get-ImmediateTreeChild `
                    -Path $rootPath `
                    -RootPath $rootPath `
                    -Depth 0 `
                    -Provider $provider `
                    -Exclude 'dir-a')

                $items.Name | Should -Be @('a.txt')
            }
        }

        It 'filters by glob exclude pattern' {
            InModuleScope ShowTree -Parameters @{ FixtureScripts = $script:FixtureScripts } {
                param([string[]] $FixtureScripts)
                foreach ($script in $FixtureScripts) { . $script }

                $rootPath = if ($IsWindows) { 'C:\Root' } else { '/root' }

                $rawChildren = @(
                    New-TestProviderItem `
                        -Name 'a.txt' `
                        -ParentPath $rootPath `
                        -Length 10

                    New-TestProviderItem `
                        -Name 'dir-a' `
                        -ParentPath $rootPath `
                        -IsDirectory
                )

                Mock Resolve-Path { $null }
                Mock Test-Path { $true }
                Mock Get-ChildItem { $rawChildren }

                $provider = New-TreeChildProvider -ProviderMode PowerShell

                $items = @(Get-ImmediateTreeChild `
                    -Path $rootPath `
                    -RootPath $rootPath `
                    -Depth 0 `
                    -Provider $provider `
                    -Exclude '*.txt')

                $items.Name | Should -Be @('dir-a')
            }
        }

        It 'allows include to rescue an excluded item' {
            InModuleScope ShowTree -Parameters @{ FixtureScripts = $script:FixtureScripts } {
                param([string[]] $FixtureScripts)
                foreach ($script in $FixtureScripts) { . $script }

                $rootPath = if ($IsWindows) { 'C:\Root' } else { '/root' }

                $rawChildren = @(
                    New-TestProviderItem `
                        -Name 'a.txt' `
                        -ParentPath $rootPath `
                        -Length 10

                    New-TestProviderItem `
                        -Name 'dir-a' `
                        -ParentPath $rootPath `
                        -IsDirectory
                )

                Mock Resolve-Path { $null }
                Mock Test-Path { $true }
                Mock Get-ChildItem { $rawChildren }

                $provider = New-TreeChildProvider -ProviderMode PowerShell

                $items = @(Get-ImmediateTreeChild `
                    -Path $rootPath `
                    -RootPath $rootPath `
                    -Depth 0 `
                    -Provider $provider `
                    -Exclude '*' `
                    -Include 'dir-a')

                $items.Name | Should -Be @('dir-a')
            }
        }

        It 'filters out files when DirectoryOnly is specified' {
            InModuleScope ShowTree -Parameters @{ FixtureScripts = $script:FixtureScripts } {
                param([string[]] $FixtureScripts)
                foreach ($script in $FixtureScripts) { . $script }

                $rootPath = if ($IsWindows) { 'C:\Root' } else { '/root' }

                $rawChildren = @(
                    New-TestProviderItem `
                        -Name 'a.txt' `
                        -ParentPath $rootPath `
                        -Length 10

                    New-TestProviderItem `
                        -Name 'dir-a' `
                        -ParentPath $rootPath `
                        -IsDirectory
                )

                Mock Resolve-Path { $null }
                Mock Test-Path { $true }
                Mock Get-ChildItem { $rawChildren }

                $provider = New-TreeChildProvider -ProviderMode PowerShell

                $items = @(Get-ImmediateTreeChild `
                    -Path $rootPath `
                    -RootPath $rootPath `
                    -Depth 0 `
                    -Provider $provider `
                    -DirectoryOnly)

                $items.Name | Should -Be @('dir-a')
                $items[0].IsContainer | Should -BeTrue
            }
        }

        It 'hides hidden items when HideHidden is specified' {
            InModuleScope ShowTree -Parameters @{ FixtureScripts = $script:FixtureScripts } {
                param([string[]] $FixtureScripts)
                foreach ($script in $FixtureScripts) { . $script }

                $rootPath = if ($IsWindows) { 'C:\Root' } else { '/root' }

                $hiddenAttributes = [IO.FileAttributes]::Hidden
                if (-not $IsWindows) {
                    $hiddenAttributes = [IO.FileAttributes]::Normal
                }

                $rawChildren = @(
                    New-TestProviderItem `
                        -Name '.hidden.txt' `
                        -ParentPath $rootPath `
                        -Length 10 `
                        -Attributes $hiddenAttributes

                    New-TestProviderItem `
                        -Name 'visible.txt' `
                        -ParentPath $rootPath `
                        -Length 10
                )

                Mock Resolve-Path { $null }
                Mock Test-Path { $true }
                Mock Get-ChildItem { $rawChildren }

                $provider = New-TreeChildProvider -ProviderMode PowerShell

                $items = @(Get-ImmediateTreeChild `
                    -Path $rootPath `
                    -RootPath $rootPath `
                    -Depth 0 `
                    -Provider $provider `
                    -HideHidden)

                $items.Name | Should -Be @('visible.txt')
            }
        }

        It 'hides system items when HideSystem is specified' -Skip:(-not $IsWindows) {
            InModuleScope ShowTree -Parameters @{ FixtureScripts = $script:FixtureScripts } {
                param([string[]] $FixtureScripts)
                foreach ($script in $FixtureScripts) { . $script }

                $rootPath = if ($IsWindows) { 'C:\Root' } else { '/root' }
                $systemAttributes = [IO.FileAttributes]::System

                $rawChildren = @(
                    New-TestProviderItem `
                        -Name 'system.txt' `
                        -ParentPath $rootPath `
                        -Length 10 `
                        -Attributes $systemAttributes

                    New-TestProviderItem `
                        -Name 'visible.txt' `
                        -ParentPath $rootPath `
                        -Length 10
                )

                Mock Resolve-Path { $null }
                Mock Test-Path { $true }
                Mock Get-ChildItem { $rawChildren }

                $provider = New-TreeChildProvider -ProviderMode PowerShell

                $items = @(Get-ImmediateTreeChild `
                    -Path $rootPath `
                    -RootPath $rootPath `
                    -Depth 0 `
                    -Provider $provider `
                    -HideSystem)

                $items.Name | Should -Be @('visible.txt')
            }
        }

        It 'sorts mocked items' {
            InModuleScope ShowTree -Parameters @{ FixtureScripts = $script:FixtureScripts } {
                param([string[]] $FixtureScripts)
                foreach ($script in $FixtureScripts) { . $script }

                $rootPath = if ($IsWindows) { 'C:\Root' } else { '/root' }

                $rawChildren = @(
                    New-TestProviderItem `
                        -Name 'b.txt' `
                        -ParentPath $rootPath `
                        -Length 0

                    New-TestProviderItem `
                        -Name 'a.txt' `
                        -ParentPath $rootPath `
                        -Length 0

                    New-TestProviderItem `
                        -Name 'dir-b' `
                        -ParentPath $rootPath `
                        -IsDirectory `
                        -Attributes ([IO.FileAttributes]::Directory)

                    New-TestProviderItem `
                        -Name 'dir-a' `
                        -ParentPath $rootPath `
                        -IsDirectory `
                        -Attributes ([IO.FileAttributes]::Directory)
                )

                Mock Resolve-Path { $null }
                Mock Test-Path { $true }
                Mock Get-ChildItem { $rawChildren }

                $provider = New-TreeChildProvider -ProviderMode PowerShell

                $items = @(Get-ImmediateTreeChild `
                    -Path $rootPath `
                    -RootPath $rootPath `
                    -Depth 0 `
                    -Provider $provider)

                $items.Name | Should -Be @('a.txt', 'b.txt', 'dir-a', 'dir-b')
            }
        }
    }

    Context 'Win32 provider mode' -Skip:(-not $IsWindows) {
        It 'uses Get-RawDirectoryEntries and returns its visible files before directories in Tree mode' {
            InModuleScope ShowTree -Parameters @{ FixtureScripts = $script:FixtureScripts } {
                param([string[]] $FixtureScripts)
                foreach ($script in $FixtureScripts) { . $script }

                $rootPath = if ($IsWindows) { 'C:\Root' } else { '/root' }

                $raw = [pscustomobject]@{
                    Files = @(
                        (New-FixtureTreeItem `
                            -Name 'b.txt' `
                            -ParentPath $rootPath `
                            -Depth 0)
                        (New-FixtureTreeItem `
                            -Name 'a.txt' `
                            -ParentPath $rootPath `
                            -Depth 0)
                    )
                    Directories = @(
                        (New-FixtureTreeItem `
                            -Name 'dir-b' `
                            -ParentPath $rootPath `
                            -Metadata @{ IsContainer = $true } `
                            -Depth 0)
                        (New-FixtureTreeItem `
                            -Name 'dir-a' `
                            -ParentPath $rootPath `
                            -Metadata @{ IsContainer = $true } `
                            -Depth 0)
                    )
                }

                Mock Resolve-Path { $null }
                Mock Test-Path { $true }
                Mock Get-RawDirectoryEntries { $raw }

                $provider = New-TreeChildProvider -ProviderMode Win32

                $items = @(Get-ImmediateTreeChild `
                    -Path $rootPath `
                    -RootPath $rootPath `
                    -Depth 0 `
                    -Provider $provider)

                $items.Name | Should -Be @(
                    'b.txt'
                    'a.txt'
                    'dir-b'
                    'dir-a'
                )

                Should -Invoke Get-RawDirectoryEntries -Times 1 -Exactly -ParameterFilter {
                    $Path -eq $rootPath -and
                            $Depth -eq 0
                }
            }
        }

        It 'preserves mocked Win32 provider order while emitting files before directories' {
            InModuleScope ShowTree -Parameters @{ FixtureScripts = $script:FixtureScripts } {
                param([string[]] $FixtureScripts)
                foreach ($script in $FixtureScripts) { . $script }

                $rootPath = if ($IsWindows) { 'C:\Root' } else { '/root' }

                $raw = [pscustomobject]@{
                    Files = @(
                        (New-FixtureTreeItem `
                            -Name 'b.txt' `
                            -ParentPath $rootPath `
                            -Depth 0)
                        (New-FixtureTreeItem `
                            -Name 'a.txt' `
                            -ParentPath $rootPath `
                            -Depth 0)
                    )
                    Directories = @(
                        (New-FixtureTreeItem `
                            -Name 'dir-b' `
                            -ParentPath $rootPath `
                            -Metadata @{ IsContainer = $true } `
                            -Depth 0)
                        (New-FixtureTreeItem `
                            -Name 'dir-a' `
                            -ParentPath $rootPath `
                            -Metadata @{ IsContainer = $true } `
                            -Depth 0)
                    )
                }

                Mock Resolve-Path { $null }
                Mock Test-Path { $true }
                Mock Get-RawDirectoryEntries { $raw }

                $provider = New-TreeChildProvider -ProviderMode Win32

                $items = @(Get-ImmediateTreeChild `
                    -Path $rootPath `
                    -RootPath $rootPath `
                    -Depth 0 `
                    -Provider $provider)

                $items.Name | Should -Be @(
                    'b.txt'
                    'a.txt'
                    'dir-b'
                    'dir-a'
                )
            }
        }

        It 'applies filtering to mocked Win32 raw entries' {
            InModuleScope ShowTree -Parameters @{ FixtureScripts = $script:FixtureScripts } {
                param([string[]] $FixtureScripts)
                foreach ($script in $FixtureScripts) { . $script }

                $rootPath = if ($IsWindows) { 'C:\Root' } else { '/root' }

                $raw = [pscustomobject]@{
                    Files = @(
                        (New-FixtureTreeItem `
                            -Name 'a.txt' `
                            -ParentPath $rootPath `
                            -Depth 0)
                    )
                    Directories = @(
                        (New-FixtureTreeItem `
                            -Name 'dir-a' `
                            -ParentPath $rootPath `
                            -Metadata @{ IsContainer = $true } `
                            -Depth 0)
                    )
                }

                Mock Resolve-Path { $null }
                Mock Test-Path { $true }
                Mock Get-RawDirectoryEntries { $raw }

                $provider = New-TreeChildProvider -ProviderMode Win32

                $items = @(Get-ImmediateTreeChild `
                    -Path $rootPath `
                    -RootPath $rootPath `
                    -Depth 0 `
                    -Provider $provider `
                    -Exclude '*.txt')

                $items.Name | Should -Be @('dir-a')
            }
        }
    }
}
