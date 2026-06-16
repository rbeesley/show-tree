# src/Tests/Unit/Enumeration/New-TreeChildProvider.Tests.ps1

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

Describe 'New-TreeChildProvider' {
    Context 'Provider object contract' {
        It 'creates a PowerShell provider by default' {
            InModuleScope ShowTree {
                $provider = New-TreeChildProvider

                $provider.PSTypeNames | Should -Contain 'ShowTree.TreeChildProvider'
                $provider.Name | Should -Be 'PowerShell'
                $provider.ProviderMode | Should -Be 'PowerShell'
                $provider.GetChildren | Should -Not -BeNullOrEmpty
            }
        }

        It 'creates an explicit PowerShell provider' {
            InModuleScope ShowTree {
                $provider = New-TreeChildProvider -ProviderMode PowerShell

                $provider.PSTypeNames | Should -Contain 'ShowTree.TreeChildProvider'
                $provider.Name | Should -Be 'PowerShell'
                $provider.ProviderMode | Should -Be 'PowerShell'
                $provider.GetChildren | Should -Not -BeNullOrEmpty
            }
        }

        It 'creates a Win32 provider' -Skip:(-not $IsWindows) {
            InModuleScope ShowTree {
                $provider = New-TreeChildProvider -ProviderMode Win32

                $provider.PSTypeNames | Should -Contain 'ShowTree.TreeChildProvider'
                $provider.Name | Should -Be 'Win32'
                $provider.ProviderMode | Should -Be 'Win32'
                $provider.GetChildren | Should -Not -BeNullOrEmpty
            }
        }
    }

    Context 'PowerShell provider' {
        It 'converts Get-ChildItem results into Files and Directories collections of TreeItem objects' {
            InModuleScope ShowTree -Parameters @{ FixtureScripts = $script:FixtureScripts } {
                param([string[]] $FixtureScripts)
                foreach ($script in $FixtureScripts) { . $script }

                $rootPath = if ($IsWindows) { 'C:\Root' } else { '/root' }

                $rawChildren = @(
                    New-TestProviderItem -Name 'dir-b' -ParentPath $rootPath -IsDirectory
                    New-TestProviderItem -Name 'b.txt' -ParentPath $rootPath -Length 20
                    New-TestProviderItem -Name 'dir-a' -ParentPath $rootPath -IsDirectory
                    New-TestProviderItem -Name 'a.txt' -ParentPath $rootPath -Length 10
                )

                Mock Resolve-Path { $null }
                Mock Test-Path { $true }
                Mock Get-ChildItem { $rawChildren }

                $provider = New-TreeChildProvider -ProviderMode PowerShell
                $result = & $provider.GetChildren $rootPath 2

                $result.Files.Count | Should -Be 2
                $result.Directories.Count | Should -Be 2

                $result.Files.Name | Should -Be @('a.txt', 'b.txt')
                $result.Directories.Name | Should -Be @('dir-a', 'dir-b')

                foreach ($item in @($result.Files) + @($result.Directories)) {
                    $item.PSTypeNames | Should -Contain 'ShowTree.TreeItem'
                    $item.Depth | Should -Be 2
                    $item.ParentPath | Should -Be $rootPath
                }

                ($result.Files | Where-Object Name -eq 'a.txt').Kind | Should -Be 'File'
                ($result.Directories | Where-Object Name -eq 'dir-a').Kind | Should -Be 'Directory'

                Should -Invoke Get-ChildItem -Times 1 -Exactly -ParameterFilter {
                    $LiteralPath -eq $rootPath -and
                            $Force -eq $true
                }
            }
        }

        It 'returns empty Files and Directories collections when the path is not a container' {
            InModuleScope ShowTree {
                $rootPath = if ($IsWindows) { 'C:\Root\file.txt' } else { '/root/file.txt' }

                Mock Resolve-Path { $null }
                Mock Test-Path { $false }
                Mock Get-ChildItem { throw 'Get-ChildItem should not be called for non-container paths.' }

                $provider = New-TreeChildProvider -ProviderMode PowerShell
                $result = & $provider.GetChildren $rootPath 0

                $result.Files | Should -BeNullOrEmpty
                $result.Directories | Should -BeNullOrEmpty

                Should -Invoke Get-ChildItem -Times 0 -Exactly
            }
        }

        It 'adds Hidden, ReadOnly, and System states from provider attributes on Windows' -Skip:(-not $IsWindows) {
            InModuleScope ShowTree -Parameters @{ FixtureScripts = $script:FixtureScripts } {
                param([string[]] $FixtureScripts)
                foreach ($script in $FixtureScripts) { . $script }

                $rootPath = if ($IsWindows) { 'C:\Root' } else { '/root' }

                $attributes = 
                        [IO.FileAttributes]::Hidden -bor
                        [IO.FileAttributes]::ReadOnly -bor
                        [IO.FileAttributes]::System

                $rawChildren = @(
                    New-TestProviderItem -Name 'metadata.txt' -ParentPath $rootPath -Attributes $attributes
                )

                Mock Resolve-Path { $null }
                Mock Test-Path { $true }
                Mock Get-ChildItem { $rawChildren }

                $provider = New-TreeChildProvider -ProviderMode PowerShell
                $result = & $provider.GetChildren $rootPath 0

                $item = $result.Files | Select-Object -First 1

                $item.States | Should -Contain 'Hidden'
                $item.States | Should -Contain 'ReadOnly'
                $item.States | Should -Contain 'System'
            }
        }

        It 'adds Symlink state and link metadata for reparse-point file items' {
            InModuleScope ShowTree -Parameters @{ FixtureScripts = $script:FixtureScripts } {
                param([string[]] $FixtureScripts)
                foreach ($script in $FixtureScripts) { . $script }

                $rootPath = if ($IsWindows) { 'C:\Root' } else { '/root' }
                $targetPath = Join-Path $rootPath 'target.txt'

                $rawChildren = @(
                    New-TestProviderItem `
                        -Name 'link.txt' `
                        -ParentPath $rootPath `
                        -Attributes ([IO.FileAttributes]::ReparsePoint) `
                        -Target $targetPath `
                        -DirectoryName $rootPath
                )

                Mock Resolve-Path { $null }
                Mock Test-Path {
                    if ($LiteralPath -eq $rootPath -and $PathType -eq 'Container') {
                        return $true
                    }

                    if ($LiteralPath -eq $targetPath) {
                        return $true
                    }

                    return $false
                }
                Mock Get-ChildItem { $rawChildren }

                $provider = New-TreeChildProvider -ProviderMode PowerShell
                $result = & $provider.GetChildren $rootPath 0

                $item = $result.Files | Select-Object -First 1

                $item.Kind | Should -Be 'Symlink'
                $item.States | Should -Contain 'Symlink'
                $item.IsLink | Should -BeTrue
                $item.Link.Type | Should -Be 'SymbolicLink'
                $item.Link.Target | Should -Be $targetPath
                $item.Link.IsBroken | Should -BeFalse
            }
        }

        It 'adds BrokenLink state when a reparse-point target is missing' {
            InModuleScope ShowTree -Parameters @{ FixtureScripts = $script:FixtureScripts } {
                param([string[]] $FixtureScripts)
                foreach ($script in $FixtureScripts) { . $script }

                $rootPath = if ($IsWindows) { 'C:\Root' } else { '/root' }
                $targetPath = Join-Path $rootPath 'missing.txt'

                $rawChildren = @(
                    New-TestProviderItem `
                        -Name 'broken.txt' `
                        -ParentPath $rootPath `
                        -Attributes ([IO.FileAttributes]::ReparsePoint) `
                        -Target $targetPath `
                        -DirectoryName $rootPath
                )

                Mock Resolve-Path { $null }
                Mock Test-Path {
                    if ($LiteralPath -eq $rootPath -and $PathType -eq 'Container') {
                        return $true
                    }

                    return $false
                }
                Mock Get-ChildItem { $rawChildren }

                $provider = New-TreeChildProvider -ProviderMode PowerShell
                $result = & $provider.GetChildren $rootPath 0

                $item = $result.Files | Select-Object -First 1

                $item.States | Should -Contain 'BrokenLink'
                $item.Link.IsBroken | Should -BeTrue
            }
        }

        # Windows Only
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

                $items.Name | Should -Not -Be @('system.txt')
                $items.Name | Should -Be @('visible.txt')
            }
        }

        # Non-Windows
        It 'adds Hidden state from dot-prefixed names on non-Windows systems' -Skip:$IsWindows {
            InModuleScope ShowTree -Parameters @{ FixtureScripts = $script:FixtureScripts } {
                param([string[]] $FixtureScripts)
                foreach ($script in $FixtureScripts) { . $script }

                $rootPath = if ($IsWindows) { 'C:\Root' } else { '/root' }

                $rawChildren = @(
                    New-TestProviderItem `
                        -Name '.hidden.txt' `
                        -ParentPath $rootPath `
                        -UnixMode "-r--r--r--"
                )

                Mock Resolve-Path { $null }
                Mock Test-Path { $true }
                Mock Get-ChildItem { $rawChildren }

                $provider = New-TreeChildProvider -ProviderMode PowerShell
                $result = & $provider.GetChildren $rootPath 0

                $item = $result.Files | Select-Object -First 1

                $item.States | Should -Contain 'Hidden'
                $item.States | Should -Contain 'NoWriteBits'
                $item.States | Should -Not -Contain 'System'
            }
        }

        It 'adds NoWriteBits state when UnixMode has no write bits' -Skip:$IsWindows {
            InModuleScope ShowTree -Parameters @{ FixtureScripts = $script:FixtureScripts } {
                param([string[]] $FixtureScripts)
                foreach ($script in $FixtureScripts) { . $script }

                $rootPath = '/root'

                $rawChildren = @(
                    New-TestProviderItem `
                            -Name 'readonly.txt' `
                            -ParentPath $rootPath `
                            -UnixMode '-r--r--r--'
                )

                Mock Resolve-Path { $null }
                Mock Test-Path { $true }
                Mock Get-ChildItem { $rawChildren }

                $provider = New-TreeChildProvider -ProviderMode PowerShell
                $result = & $provider.GetChildren $rootPath 0

                $item = $result.Files | Select-Object -First 1

                $item.States | Should -Contain 'NoWriteBits'
                $item.States | Should -Not -Contain 'OwnerWritable'
                $item.States | Should -Not -Contain 'GroupWritable'
                $item.States | Should -Not -Contain 'OtherWritable'
            }
        }

        It 'adds OwnerWritable state from UnixMode owner write bit' -Skip:$IsWindows {
            InModuleScope ShowTree -Parameters @{ FixtureScripts = $script:FixtureScripts } {
                param([string[]] $FixtureScripts)
                foreach ($script in $FixtureScripts) { . $script }

                $rootPath = '/root'

                $rawChildren = @(
                    New-TestProviderItem `
                            -Name 'owner-writable.txt' `
                            -ParentPath $rootPath `
                            -UnixMode '-rw-r--r--'
                )

                Mock Resolve-Path { $null }
                Mock Test-Path { $true }
                Mock Get-ChildItem { $rawChildren }

                $provider = New-TreeChildProvider -ProviderMode PowerShell
                $result = & $provider.GetChildren $rootPath 0

                $item = $result.Files | Select-Object -First 1

                $item.States | Should -Contain 'OwnerWritable'
                $item.States | Should -Not -Contain 'GroupWritable'
                $item.States | Should -Not -Contain 'OtherWritable'
                $item.States | Should -Not -Contain 'NoWriteBits'
            }
        }

        It 'adds GroupWritable state from UnixMode group write bit' -Skip:$IsWindows {
            InModuleScope ShowTree -Parameters @{ FixtureScripts = $script:FixtureScripts } {
                param([string[]] $FixtureScripts)
                foreach ($script in $FixtureScripts) { . $script }

                $rootPath = '/root'

                $rawChildren = @(
                    New-TestProviderItem `
                            -Name 'group-writable.txt' `
                            -ParentPath $rootPath `
                            -UnixMode '-r--rw-r--'
                )

                Mock Resolve-Path { $null }
                Mock Test-Path { $true }
                Mock Get-ChildItem { $rawChildren }

                $provider = New-TreeChildProvider -ProviderMode PowerShell
                $result = & $provider.GetChildren $rootPath 0

                $item = $result.Files | Select-Object -First 1

                $item.States | Should -Not -Contain 'OwnerWritable'
                $item.States | Should -Contain 'GroupWritable'
                $item.States | Should -Not -Contain 'OtherWritable'
                $item.States | Should -Not -Contain 'NoWriteBits'
            }
        }

        It 'adds OtherWritable state from UnixMode other write bit' -Skip:$IsWindows {
            InModuleScope ShowTree -Parameters @{ FixtureScripts = $script:FixtureScripts } {
                param([string[]] $FixtureScripts)
                foreach ($script in $FixtureScripts) { . $script }

                $rootPath = '/root'

                $rawChildren = @(
                    New-TestProviderItem `
                            -Name 'other-writable.txt' `
                            -ParentPath $rootPath `
                            -UnixMode '-r--r--rw-'
                )

                Mock Resolve-Path { $null }
                Mock Test-Path { $true }
                Mock Get-ChildItem { $rawChildren }

                $provider = New-TreeChildProvider -ProviderMode PowerShell
                $result = & $provider.GetChildren $rootPath 0

                $item = $result.Files | Select-Object -First 1

                $item.States | Should -Not -Contain 'OwnerWritable'
                $item.States | Should -Not -Contain 'GroupWritable'
                $item.States | Should -Contain 'OtherWritable'
                $item.States | Should -Not -Contain 'NoWriteBits'
            }
        }

        It 'adds multiple Unix writable states when multiple write bits are set' -Skip:$IsWindows {
            InModuleScope ShowTree -Parameters @{ FixtureScripts = $script:FixtureScripts } {
                param([string[]] $FixtureScripts)
                foreach ($script in $FixtureScripts) { . $script }

                $rootPath = '/root'

                $rawChildren = @(
                    New-TestProviderItem `
                            -Name 'owner-group-writable.txt' `
                            -ParentPath $rootPath `
                            -UnixMode '-rw-rw-r--'
                )

                Mock Resolve-Path { $null }
                Mock Test-Path { $true }
                Mock Get-ChildItem { $rawChildren }

                $provider = New-TreeChildProvider -ProviderMode PowerShell
                $result = & $provider.GetChildren $rootPath 0

                $item = $result.Files | Select-Object -First 1

                $item.States | Should -Contain 'OwnerWritable'
                $item.States | Should -Contain 'GroupWritable'
                $item.States | Should -Not -Contain 'OtherWritable'
                $item.States | Should -Not -Contain 'NoWriteBits'
            }
        }
    }

    Context 'Win32 provider' -Skip:(-not $IsWindows) {
        It 'delegates to Get-RawDirectoryEntries' {
            InModuleScope ShowTree -Parameters @{ FixtureScripts = $script:FixtureScripts } {
                param([string[]] $FixtureScripts)
                foreach ($script in $FixtureScripts) { . $script }

                $rootPath = if ($IsWindows) { 'C:\Root' } else { '/root' }

                $raw = [PSCustomObject]@{
                    Files = @(
                        New-FixtureTreeItem `
                            -Name 'file.txt' `
                            -ParentPath $rootPath `
                            -Depth 3
                    )
                    Directories = @(
                        New-FixtureTreeItem `
                            -Name 'dir' `
                            -ParentPath $rootPath `
                            -Metadata @{ IsContainer = $true } `
                            -Depth 3
                    )
                }

                Mock Get-RawDirectoryEntries { $raw }

                $provider = New-TreeChildProvider -ProviderMode Win32
                $result = & $provider.GetChildren $rootPath 3

                $result | Should -Be $raw
                $result.Files.Name | Should -Be @('file.txt')
                $result.Directories.Name | Should -Be @('dir')

                Should -Invoke Get-RawDirectoryEntries -Times 1 -Exactly -ParameterFilter {
                    $Path -eq $rootPath -and
                            $Depth -eq 3
                }
            }
        }
    }
}
