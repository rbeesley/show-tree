# src/Tests/Unit/Enumeration/Invoke-TreeTraversal.Tests.ps1

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

Describe 'Invoke-TreeTraversal' {
    It 'emits Item records for immediate children' {
        InModuleScope ShowTree -Parameters @{ FixtureScripts = $script:FixtureScripts } {
            param([string[]] $FixtureScripts)
            foreach ($script in $FixtureScripts) { . $script }

            $rootPath = if ($IsWindows) { 'C:\Root' } else { '/root' }

            $provider = [PSCustomObject]@{
                Name = 'Test'
                GetChildren = {
                    param([string] $Path, [int] $Depth)

                    if ($Path -ne $rootPath) {
                        return [PSCustomObject]@{
                            Files       = @()
                            Directories = @()
                        }
                    }

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

            $records = @(
                Invoke-TreeTraversal `
                    -Path $rootPath `
                    -RootPath $rootPath `
                    -MaxDepth 0 `
                    -Provider $provider
            )

            $records.Count | Should -Be 3
            $records.RecordType | Should -Be @('Item', 'Gap', 'Item')

            foreach ($record in $records) {
                $record.PSTypeNames | Should -Contain 'ShowTree.TreeRecord'
            }

            ($records | Where-Object RecordType -eq 'Item').TreeItem.Name | Should -Be @(
                'file-a.txt'
                'dir-a'
            )

            $records[1].TreeItem | Should -BeNullOrEmpty
            $records[1].TreeLayout.PSTypeNames | Should -Contain 'ShowTree.TreeLayout'
        }
    }

    It 'computes IsLastSibling for each sibling in the immediate group' {
        InModuleScope ShowTree -Parameters @{ FixtureScripts = $script:FixtureScripts } {
            param([string[]] $FixtureScripts)
            foreach ($script in $FixtureScripts) { . $script }

            $rootPath = if ($IsWindows) { 'C:\Root' } else { '/root' }

            $provider = [PSCustomObject]@{
                Name = 'Test'
                GetChildren = {
                    param([string] $Path, [int] $Depth)

                    if ($Path -ne $rootPath) {
                        return [PSCustomObject]@{
                            Files       = @()
                            Directories = @()
                        }
                    }

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

                            New-FixtureTreeItem `
                                -Name 'dir-b' `
                                -ParentPath $Path `
                                -Metadata @{ IsContainer = $true } `
                                -Depth $Depth
                        )
                    }
                }
            }

            $records = @(
                Invoke-TreeTraversal `
                    -Path $rootPath `
                    -RootPath $rootPath `
                    -MaxDepth 0 `
                    -Provider $provider
            )

            $itemRecords = @($records | Where-Object RecordType -eq 'Item')

            $itemRecords.TreeItem.Name | Should -Be @(
                'file-a.txt'
                'dir-a'
                'dir-b'
            )

            $itemRecords[0].TreeLayout.IsLastSibling | Should -BeFalse
            $itemRecords[1].TreeLayout.IsLastSibling | Should -BeFalse
            $itemRecords[2].TreeLayout.IsLastSibling | Should -BeTrue
        }
    }

    It 'computes HasLaterSiblingDirectory for each item' {
        InModuleScope ShowTree -Parameters @{ FixtureScripts = $script:FixtureScripts } {
            param([string[]] $FixtureScripts)
            foreach ($script in $FixtureScripts) { . $script }

            $rootPath = if ($IsWindows) { 'C:\Root' } else { '/root' }

            $provider = [PSCustomObject]@{
                Name = 'Test'
                GetChildren = {
                    param([string] $Path, [int] $Depth)

                    if ($Path -ne $rootPath) {
                        return [PSCustomObject]@{
                            Files       = @()
                            Directories = @()
                        }
                    }

                    [PSCustomObject]@{
                        Files = @(
                            New-FixtureTreeItem `
                                -Name 'file-a.txt' `
                                -ParentPath $Path `
                                -Depth $Depth

                            New-FixtureTreeItem `
                                -Name 'file-b.txt' `
                                -ParentPath $Path `
                                -Depth $Depth
                        )
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
            }

            $records = @(
                Invoke-TreeTraversal `
                    -Path $rootPath `
                    -RootPath $rootPath `
                    -MaxDepth 0 `
                    -Provider $provider
            )

            $itemRecords = @($records | Where-Object RecordType -eq 'Item')

            $itemRecords.TreeItem.Name | Should -Be @(
                'file-a.txt'
                'file-b.txt'
                'dir-a'
                'dir-b'
            )

            $itemRecords[0].TreeLayout.HasLaterSiblingDirectory | Should -BeTrue
            $itemRecords[1].TreeLayout.HasLaterSiblingDirectory | Should -BeTrue
            $itemRecords[2].TreeLayout.HasLaterSiblingDirectory | Should -BeTrue
            $itemRecords[3].TreeLayout.HasLaterSiblingDirectory | Should -BeFalse
        }
    }

    It 'recurses depth-first when MaxDepth allows recursion' {
        InModuleScope ShowTree -Parameters @{ FixtureScripts = $script:FixtureScripts } {
            param([string[]] $FixtureScripts)
            foreach ($script in $FixtureScripts) { . $script }

            $rootPath = if ($IsWindows) { 'C:\Root' } else { '/root' }
            $dirAPath = Join-Path $rootPath 'dir-a'
            $dirBPath = Join-Path $rootPath 'dir-b'

            $provider = [PSCustomObject]@{
                Name = 'Test'
                GetChildren = {
                    param([string] $Path, [int] $Depth)

                    if ($Path -eq $rootPath) {
                        return [PSCustomObject]@{
                            Files = @(
                                New-FixtureTreeItem `
                                    -Name 'file-root.txt' `
                                    -ParentPath $Path `
                                    -Depth $Depth
                            )
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
                                    -Name 'file-a.txt' `
                                    -ParentPath $Path `
                                    -Depth $Depth
                            )
                            Directories = @()
                        }
                    }

                    if ($Path -eq $dirBPath) {
                        return [PSCustomObject]@{
                            Files = @(
                                New-FixtureTreeItem `
                                    -Name 'file-b.txt' `
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

            $records = @(
                Invoke-TreeTraversal `
                    -Path $rootPath `
                    -RootPath $rootPath `
                    -MaxDepth 1 `
                    -Provider $provider
            )

            $records.RecordType | Should -Be @(
                'Item'
                'Gap'
                'Item'
                'Item'
                'Gap'
                'Item'
                'Item'
            )

            ($records | Where-Object RecordType -eq 'Item').TreeItem.Name | Should -Be @(
                'file-root.txt'
                'dir-a'
                'file-a.txt'
                'dir-b'
                'file-b.txt'
            )

            ($records | Where-Object RecordType -eq 'Gap').Count | Should -Be 2
        }
    }

    It 'does not recurse when MaxDepth is reached' {
        InModuleScope ShowTree -Parameters @{ FixtureScripts = $script:FixtureScripts } {
            param([string[]] $FixtureScripts)
            foreach ($script in $FixtureScripts) { . $script }

            $rootPath = if ($IsWindows) { 'C:\Root' } else { '/root' }
            $dirAPath = Join-Path $rootPath 'dir-a'

            $providerCallCount = 0

            $provider = [PSCustomObject]@{
                Name = 'Test'
                GetChildren = {
                    param([string] $Path, [int] $Depth)

                    $script:ProviderCallCount++

                    if ($Path -eq $rootPath) {
                        return [PSCustomObject]@{
                            Files = @()
                            Directories = @(
                                New-FixtureTreeItem `
                                    -Name 'dir-a' `
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
                                    -Name 'nested.txt' `
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

            $script:ProviderCallCount = 0

            $records = @(
                Invoke-TreeTraversal `
                    -Path $rootPath `
                    -RootPath $rootPath `
                    -MaxDepth 0 `
                    -Provider $provider
            )

            $records.TreeItem.Name | Should -Be @('dir-a')
            $records.TreeItem.Name | Should -Not -Contain 'nested.txt'
            $script:ProviderCallCount | Should -Be 1
        }
    }

    It 'passes ancestor sibling state to descendant records' {
        InModuleScope ShowTree -Parameters @{ FixtureScripts = $script:FixtureScripts } {
            param([string[]] $FixtureScripts)
            foreach ($script in $FixtureScripts) { . $script }

            $rootPath = if ($IsWindows) { 'C:\Root' } else { '/root' }
            $dirAPath = Join-Path $rootPath 'dir-a'
            $dirBPath = Join-Path $rootPath 'dir-b'

            $provider = [PSCustomObject]@{
                Name = 'Test'
                GetChildren = {
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

                    if ($Path -eq $dirBPath) {
                        return [PSCustomObject]@{
                            Files = @(
                                New-FixtureTreeItem `
                                    -Name 'inside-b.txt' `
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

            $records = @(
                Invoke-TreeTraversal `
                    -Path $rootPath `
                    -RootPath $rootPath `
                    -MaxDepth 1 `
                    -Provider $provider
            )

            $insideA = $records | Where-Object { $_.TreeItem.Name -eq 'inside-a.txt' } | Select-Object -First 1
            $insideB = $records | Where-Object { $_.TreeItem.Name -eq 'inside-b.txt' } | Select-Object -First 1

            $insideA.TreeLayout.AncestorIsLastSibling | Should -Be @($false)
            $insideB.TreeLayout.AncestorIsLastSibling | Should -Be @($true)
        }
    }

    It 'emits a Gap record after a directory subtree when that directory has a later sibling' {
        InModuleScope ShowTree -Parameters @{ FixtureScripts = $script:FixtureScripts } {
            param([string[]] $FixtureScripts)
            foreach ($script in $FixtureScripts) { . $script }

            $rootPath = if ($IsWindows) { 'C:\Root' } else { '/root' }
            $dirAPath = Join-Path $rootPath 'dir-a'

            $provider = [PSCustomObject]@{
                Name = 'Test'
                GetChildren = {
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

            $records = @(
                Invoke-TreeTraversal `
                    -Path $rootPath `
                    -RootPath $rootPath `
                    -MaxDepth 1 `
                    -Provider $provider
            )

            $records.RecordType | Should -Be @(
                'Item'
                'Item'
                'Gap'
                'Item'
            )

            $records[0].TreeItem.Name | Should -Be 'dir-a'
            $records[1].TreeItem.Name | Should -Be 'inside-a.txt'
            $records[2].TreeItem | Should -BeNullOrEmpty
            $records[2].TreeLayout.PSTypeNames | Should -Contain 'ShowTree.TreeLayout'
            $records[3].TreeItem.Name | Should -Be 'dir-b'
        }
    }

    It 'does not emit a Gap record after an empty directory' {
        InModuleScope ShowTree -Parameters @{ FixtureScripts = $script:FixtureScripts } {
            param([string[]] $FixtureScripts)
            foreach ($script in $FixtureScripts) { . $script }

            $rootPath = if ($IsWindows) { 'C:\Root' } else { '/root' }

            $provider = [PSCustomObject]@{
                Name = 'Test'
                GetChildren = {
                    param([string] $Path, [int] $Depth)

                    if ($Path -eq $rootPath) {
                        return [PSCustomObject]@{
                            Files = @()
                            Directories = @(
                                New-FixtureTreeItem `
                                    -Name 'empty-dir' `
                                    -ParentPath $Path `
                                    -Metadata @{ IsContainer = $true } `
                                    -Depth $Depth

                                New-FixtureTreeItem `
                                    -Name 'next-dir' `
                                    -ParentPath $Path `
                                    -Metadata @{ IsContainer = $true } `
                                    -Depth $Depth
                            )
                        }
                    }

                    [PSCustomObject]@{
                        Files       = @()
                        Directories = @()
                    }
                }
            }

            $records = @(
                Invoke-TreeTraversal `
                    -Path $rootPath `
                    -RootPath $rootPath `
                    -MaxDepth 1 `
                    -Provider $provider
            )

            $records.RecordType | Should -Be @(
                'Item'
                'Item'
            )

            $records.TreeItem.Name | Should -Be @(
                'empty-dir'
                'next-dir'
            )
        }
    }

    It 'does not emit inner gaps for a single-child directory chain' {
        InModuleScope ShowTree -Parameters @{ FixtureScripts = $script:FixtureScripts } {
            param([string[]] $FixtureScripts)
            foreach ($script in $FixtureScripts) { . $script }

            $rootPath = if ($IsWindows) { 'C:\Root' } else { '/root' }
            $aPath = Join-Path $rootPath 'a'
            $bPath = Join-Path $aPath 'b'
            $cPath = Join-Path $bPath 'c'

            $provider = [PSCustomObject]@{
                Name = 'Test'
                GetChildren = {
                    param([string] $Path, [int] $Depth)

                    if ($Path -eq $rootPath) {
                        return [PSCustomObject]@{
                            Files = @()
                            Directories = @(
                                New-FixtureTreeItem `
                                    -Name 'a' `
                                    -ParentPath $Path `
                                    -Metadata @{ IsContainer = $true } `
                                    -Depth $Depth

                                New-FixtureTreeItem `
                                    -Name 'next' `
                                    -ParentPath $Path `
                                    -Metadata @{ IsContainer = $true } `
                                    -Depth $Depth
                            )
                        }
                    }

                    if ($Path -eq $aPath) {
                        return [PSCustomObject]@{
                            Files = @()
                            Directories = @(
                                New-FixtureTreeItem `
                                    -Name 'b' `
                                    -ParentPath $Path `
                                    -Metadata @{ IsContainer = $true } `
                                    -Depth $Depth
                            )
                        }
                    }

                    if ($Path -eq $bPath) {
                        return [PSCustomObject]@{
                            Files = @()
                            Directories = @(
                                New-FixtureTreeItem `
                                    -Name 'c' `
                                    -ParentPath $Path `
                                    -Metadata @{ IsContainer = $true } `
                                    -Depth $Depth
                            )
                        }
                    }

                    if ($Path -eq $cPath) {
                        return [PSCustomObject]@{
                            Files = @(
                                New-FixtureTreeItem `
                                    -Name 'leaf.txt' `
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

            $records = @(
                Invoke-TreeTraversal `
                    -Path $rootPath `
                    -RootPath $rootPath `
                    -MaxDepth -1 `
                    -Provider $provider
            )

            $records.RecordType | Should -Be @(
                'Item'
                'Item'
                'Item'
                'Item'
                'Gap'
                'Item'
            )

            ($records | Where-Object RecordType -eq 'Item').TreeItem.Name | Should -Be @(
                'a'
                'b'
                'c'
                'leaf.txt'
                'next'
            )

            ($records | Where-Object RecordType -eq 'Gap').Count | Should -Be 1
        }
    }

    It 'does not emit a trailing Gap record after the last sibling subtree' {
        InModuleScope ShowTree -Parameters @{ FixtureScripts = $script:FixtureScripts } {
            param([string[]] $FixtureScripts)
            foreach ($script in $FixtureScripts) { . $script }

            $rootPath = if ($IsWindows) { 'C:\Root' } else { '/root' }
            $dirAPath = Join-Path $rootPath 'dir-a'

            $provider = [PSCustomObject]@{
                Name = 'Test'
                GetChildren = {
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

            $records = @(
                Invoke-TreeTraversal `
                    -Path $rootPath `
                    -RootPath $rootPath `
                    -MaxDepth 1 `
                    -Provider $provider
            )

            $records.RecordType | Should -Be @(
                'Item'
                'Item'
            )

            $records.RecordType | Should -Not -Contain 'Gap'
        }
    }

    It 'emits mixed Item and Gap records with TreeItem only on Item records' {
        InModuleScope ShowTree -Parameters @{ FixtureScripts = $script:FixtureScripts } {
            param([string[]] $FixtureScripts)
            foreach ($script in $FixtureScripts) { . $script }

            $rootPath = if ($IsWindows) { 'C:\Root' } else { '/root' }
            $dirAPath = Join-Path $rootPath 'dir-a'

            $provider = [PSCustomObject]@{
                Name = 'Test'
                GetChildren = {
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

            $records = @(
                Invoke-TreeTraversal `
                -Path $rootPath `
                -RootPath $rootPath `
                -MaxDepth 1 `
                -Provider $provider
            )

            $records.RecordType | Should -Be @(
                'Item'
                'Item'
                'Gap'
                'Item'
            )

            ($records | Where-Object RecordType -eq 'Item').TreeItem.Name | Should -Be @(
                'dir-a'
                'inside-a.txt'
                'dir-b'
            )

            $gap = $records | Where-Object RecordType -eq 'Gap' | Select-Object -First 1
            $gap.TreeItem | Should -BeNullOrEmpty
            $gap.TreeLayout.PSTypeNames | Should -Contain 'ShowTree.TreeLayout'
        }
    }

    It 'emits a Gap record between files and following directories in the same sibling group' {
        InModuleScope ShowTree -Parameters @{ FixtureScripts = $script:FixtureScripts } {
            param([string[]] $FixtureScripts)
            foreach ($script in $FixtureScripts) { . $script }

            $rootPath = if ($IsWindows) { 'C:\Root' } else { '/root' }

            $provider = [PSCustomObject]@{
                Name = 'Test'
                GetChildren = {
                    param([string] $Path, [int] $Depth)

                    if ($Path -eq $rootPath) {
                        return [PSCustomObject]@{
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

                    [PSCustomObject]@{
                        Files       = @()
                        Directories = @()
                    }
                }
            }

            $records = @(
                Invoke-TreeTraversal `
                    -Path $rootPath `
                    -RootPath $rootPath `
                    -MaxDepth 0 `
                    -Provider $provider
            )

            $records.RecordType | Should -Be @(
                'Item'
                'Gap'
                'Item'
            )

            $records[0].TreeItem.Name | Should -Be 'file-a.txt'
            $records[1].TreeItem | Should -BeNullOrEmpty
            $records[1].TreeLayout.AncestorIsLastSibling | Should -Be @()
            $records[2].TreeItem.Name | Should -Be 'dir-a'
        }
    }

    It 'emits closing subtree Gap records at the parent sibling level' {
        InModuleScope ShowTree -Parameters @{ FixtureScripts = $script:FixtureScripts } {
            param([string[]] $FixtureScripts)
            foreach ($script in $FixtureScripts) { . $script }

            $rootPath = if ($IsWindows) { 'C:\Root' } else { '/root' }
            $dirAPath = Join-Path $rootPath 'dir-a'

            $provider = [PSCustomObject]@{
                Name = 'Test'
                GetChildren = {
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

            $records = @(
                Invoke-TreeTraversal `
                    -Path $rootPath `
                    -RootPath $rootPath `
                    -MaxDepth 1 `
                    -Provider $provider
            )

            $records.RecordType | Should -Be @(
                'Item'
                'Item'
                'Gap'
                'Item'
            )

            $gap = $records[2]

            $gap.RecordType | Should -Be 'Gap'
            $gap.TreeItem | Should -BeNullOrEmpty
            $gap.TreeLayout.Depth | Should -Be 0
            $gap.TreeLayout.RelativeDepth | Should -Be 0
            $gap.TreeLayout.AncestorIsLastSibling | Should -Be @()
        }
    }

    It 'generates correct records for a complex structure with various file types and attributes' -Skip {
        InModuleScope ShowTree -Parameters @{ FixtureScripts = $script:FixtureScripts } {
            param([string[]] $FixtureScripts)
            foreach ($script in $FixtureScripts) { . $script }

            $structure = [ordered]@{
                "dir-1" = [ordered]@{
                    "file-1-1.txt" = $null
                    "dir-1-1"      = [ordered]@{
                        "file-1-1-1.txt" = $null
                    }
                    "file-1-2.txt" = $null
                }
                "link-dir" = @{
                    IsSymlink = $true
                    Target    = "C:\Elsewhere"
                    Children  = [ordered]@{
                        "nested-in-link.txt" = $null
                    }
                }
                "hidden-file.tmp" = @{ IsHidden = $true }
                "system-file.sys" = @{ Kind = "File"; Native = @{ FileAttributes = [IO.FileAttributes]::System } }
                "dir-2" = [ordered]@{
                    "file-2-1.txt" = $null
                }
            }

            $tree = New-FixtureTree -Structure $structure
            $provider = New-FixtureTreeChildProvider -Root $tree
            $records = @(
                Invoke-TreeTraversal -Path $provider.RootPath -Provider $provider
            )

            $code = $records | Convert-TreeRecordToFixtureStructure
            # $code | Set-Clipboard
            $code | Out-Host
        }
    }
}
