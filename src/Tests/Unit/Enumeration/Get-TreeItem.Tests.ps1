# src/Tests/Unit/Enumeration/Get-TreeItem.Tests.ps1

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

Describe 'Get-TreeItem behavior' {
    It 'emits TreeRecord objects for files and directories' {
        InModuleScope ShowTree -Parameters @{ FixtureScripts = $script:FixtureScripts } {
            param([string[]] $FixtureScripts)
            foreach ($script in $FixtureScripts) { . $script }

            $parentPath = $IsWindows ? 'C:\' : '/tmp'
            $rootPath = Join-Path $parentPath 'Root'

            $structure = [ordered]@{
                'File2.txt' = $null
                Dir1 = [ordered]@{
                    'File1.txt' = $null
                }
            }

            $tree = New-FixtureTree -Structure $structure -ParentPath $parentPath
            $provider = New-TestTreeChildProvider -Root $tree

            Mock Resolve-Path {
                [PSCustomObject]@{
                    ProviderPath = $rootPath
                    Path         = $rootPath
                }
            }

            Mock New-TreeChildProvider {
                $provider
            }

            $records = @(Get-TreeItem -Path $rootPath -Depth 0)
            $itemRecords = @($records | Where-Object RecordType -eq 'Item')

            $records | Should -Not -BeNullOrEmpty
            foreach ($record in $records) {
                $record.PSTypeNames | Should -Contain 'ShowTree.TreeRecord'
            }

            $itemRecords.TreeItem.Name | Should -Be @(
                'File2.txt'
                'Dir1'
            )
        }
    }

    It 'recurses to the requested public depth' {
        InModuleScope ShowTree -Parameters @{ FixtureScripts = $script:FixtureScripts } {
            param([string[]] $FixtureScripts)
            foreach ($script in $FixtureScripts) { . $script }

            $parentPath = $IsWindows ? 'C:\' : '/tmp'
            $rootPath = Join-Path $parentPath 'Root'

            $structure = [ordered]@{
                Dir1 = [ordered]@{
                    'File1.txt' = $null
                    Nested = [ordered]@{
                        'TooDeep.txt' = $null
                    }
                }
                'File2.txt' = $null
            }

            $tree = New-FixtureTree -Structure $structure -ParentPath $parentPath
            $provider = New-TestTreeChildProvider -Root $tree

            Mock Resolve-Path {
                [PSCustomObject]@{
                    ProviderPath = $rootPath
                    Path         = $rootPath
                }
            }

            Mock New-TreeChildProvider {
                $provider
            }

            $records = @(Get-TreeItem -Path $rootPath -Depth 2)
            $itemNames = @($records | Where-Object RecordType -eq 'Item' | ForEach-Object { $_.TreeItem.Name })

            $itemNames | Should -Contain 'Dir1'
            $itemNames | Should -Contain 'File1.txt'
            $itemNames | Should -Contain 'File2.txt'
            $itemNames | Should -Not -Contain 'TooDeep.txt'
        }
    }

    It 'excludes items by exact name and prunes excluded subtrees' {
        InModuleScope ShowTree -Parameters @{ FixtureScripts = $script:FixtureScripts } {
            param([string[]] $FixtureScripts)
            foreach ($script in $FixtureScripts) { . $script }

            $parentPath = $IsWindows ? 'C:\' : '/tmp'
            $rootPath = Join-Path $parentPath 'Root'

            $structure = [ordered]@{
                Dir1 = [ordered]@{
                    'File1.txt' = $null
                }
                'File2.txt' = $null
            }

            $tree = New-FixtureTree -Structure $structure -ParentPath $parentPath
            $provider = New-TestTreeChildProvider -Root $tree

            Mock Resolve-Path {
                [PSCustomObject]@{
                    ProviderPath = $rootPath
                    Path         = $rootPath
                }
            }

            Mock New-TreeChildProvider {
                $provider
            }

            $records = @(Get-TreeItem -Path $rootPath -Depth 2 -Exclude 'Dir1')
            $itemNames = @($records | Where-Object RecordType -eq 'Item' | ForEach-Object { $_.TreeItem.Name })

            $itemNames | Should -Not -Contain 'Dir1'
            $itemNames | Should -Not -Contain 'File1.txt'
            $itemNames | Should -Contain 'File2.txt'
        }
    }

    It 'excludes files by glob pattern' {
        InModuleScope ShowTree -Parameters @{ FixtureScripts = $script:FixtureScripts } {
            param([string[]] $FixtureScripts)
            foreach ($script in $FixtureScripts) { . $script }

            $parentPath = $IsWindows ? 'C:\' : '/tmp'
            $rootPath = Join-Path $parentPath 'Root'

            $structure = [ordered]@{
                Dir1 = [ordered]@{}
                'File2.txt' = $null
                'File3.log' = $null
            }

            $tree = New-FixtureTree -Structure $structure -ParentPath $parentPath
            $provider = New-TestTreeChildProvider -Root $tree

            Mock Resolve-Path {
                [PSCustomObject]@{
                    ProviderPath = $rootPath
                    Path         = $rootPath
                }
            }

            Mock New-TreeChildProvider {
                $provider
            }

            $records = @(Get-TreeItem -Path $rootPath -Depth 1 -Exclude '*.txt')
            $itemNames = @($records | Where-Object RecordType -eq 'Item' | ForEach-Object { $_.TreeItem.Name })

            $itemNames | Should -Not -Contain 'File2.txt'
            $itemNames | Should -Contain 'File3.log'
            $itemNames | Should -Contain 'Dir1'
        }
    }

    It 'allows include to rescue an excluded item' {
        InModuleScope ShowTree -Parameters @{ FixtureScripts = $script:FixtureScripts } {
            param([string[]] $FixtureScripts)
            foreach ($script in $FixtureScripts) { . $script }

            $parentPath = $IsWindows ? 'C:\' : '/tmp'
            $rootPath = Join-Path $parentPath 'Root'

            $structure = [ordered]@{
                Dir1 = [ordered]@{
                    'File1.txt' = $null
                }
                'File2.txt' = $null
            }

            $tree = New-FixtureTree -Structure $structure -ParentPath $parentPath
            $provider = New-TestTreeChildProvider -Root $tree

            Mock Resolve-Path {
                [PSCustomObject]@{
                    ProviderPath = $rootPath
                    Path         = $rootPath
                }
            }

            Mock New-TreeChildProvider {
                $provider
            }

            $records = @(Get-TreeItem -Path $rootPath -Depth 1 -Exclude '*' -Include 'Dir1')
            $itemNames = @($records | Where-Object RecordType -eq 'Item' | ForEach-Object { $_.TreeItem.Name })

            $itemNames | Should -Contain 'Dir1'
            $itemNames | Should -Not -Contain 'File2.txt'
        }
    }

    It 'filters out files when DirectoryOnly is specified but still recurses into directories' {
        InModuleScope ShowTree -Parameters @{ FixtureScripts = $script:FixtureScripts } {
            param([string[]] $FixtureScripts)
            foreach ($script in $FixtureScripts) { . $script }

            $parentPath = $IsWindows ? 'C:\' : '/tmp'
            $rootPath = Join-Path $parentPath 'Root'

            $structure = [ordered]@{
                Dir1 = [ordered]@{
                    'File1.txt' = $null
                    Nested = [ordered]@{
                        'File2.txt' = $null
                    }
                }
            }

            $tree = New-FixtureTree -Structure $structure -ParentPath $parentPath
            $provider = New-TestTreeChildProvider -Root $tree

            Mock Resolve-Path {
                [PSCustomObject]@{
                    ProviderPath = $rootPath
                    Path         = $rootPath
                }
            }

            Mock New-TreeChildProvider {
                $provider
            }

            $records = @(Get-TreeItem -Path $rootPath -Depth 2 -DirectoryOnly)
            $itemNames = @($records | Where-Object RecordType -eq 'Item' | ForEach-Object { $_.TreeItem.Name })

            $itemNames | Should -Contain 'Dir1'
            $itemNames | Should -Contain 'Nested'
            $itemNames | Should -Not -Contain 'File1.txt'
            $itemNames | Should -Not -Contain 'File2.txt'
        }
    }

    It 'does not follow links by default' {
        InModuleScope ShowTree -Parameters @{ FixtureScripts = $script:FixtureScripts } {
            param([string[]] $FixtureScripts)
            foreach ($script in $FixtureScripts) { . $script }

            $parentPath = $IsWindows ? 'C:\' : '/tmp'
            $rootPath = Join-Path $parentPath 'Root'

            $structure = [ordered]@{
                LinkDir = @{
                    IsSymlink = $true
                    Children = [ordered]@{
                        'TargetFile.txt' = $null
                    }
                }
            }

            $tree = New-FixtureTree -Structure $structure -ParentPath $parentPath
            $provider = New-TestTreeChildProvider -Root $tree

            Mock Resolve-Path {
                [PSCustomObject]@{
                    ProviderPath = $rootPath
                    Path         = $rootPath
                }
            }

            Mock New-TreeChildProvider {
                $provider
            }

            $records = @(Get-TreeItem -Path $rootPath -Depth 2)
            $itemNames = @($records | Where-Object RecordType -eq 'Item' | ForEach-Object { $_.TreeItem.Name })

            $itemNames | Should -Contain 'LinkDir'
            $itemNames | Should -Not -Contain 'TargetFile.txt'
        }
    }

    It 'follows links when FollowLinks is specified' {
        InModuleScope ShowTree -Parameters @{ FixtureScripts = $script:FixtureScripts } {
            param([string[]] $FixtureScripts)
            foreach ($script in $FixtureScripts) { . $script }

            $parentPath = $IsWindows ? 'C:\' : '/tmp'
            $rootPath = Join-Path $parentPath 'Root'

            $structure = [ordered]@{
                LinkDir = @{
                    IsSymlink = $true
                    Children = [ordered]@{
                        'TargetFile.txt' = $null
                    }
                }
            }

            $tree = New-FixtureTree -Structure $structure -ParentPath $parentPath
            $provider = New-TestTreeChildProvider -Root $tree

            Mock Resolve-Path {
                [PSCustomObject]@{
                    ProviderPath = $rootPath
                    Path         = $rootPath
                }
            }

            Mock New-TreeChildProvider {
                $provider
            }

            $records = @(Get-TreeItem -Path $rootPath -Depth 2 -FollowLinks)
            $itemNames = @($records | Where-Object RecordType -eq 'Item' | ForEach-Object { $_.TreeItem.Name })

            $itemNames | Should -Contain 'LinkDir'
            $itemNames | Should -Contain 'TargetFile.txt'
        }
    }
}

Describe 'Get-TreeItem' {
    It 'creates a provider and invokes streaming traversal' {
        InModuleScope ShowTree -Parameters @{ FixtureScripts = $script:FixtureScripts } {
            param([string[]] $FixtureScripts)
            foreach ($script in $FixtureScripts) { . $script }

            $rootPath = $IsWindows ? 'C:\Root' : '/root'

            $provider = [PSCustomObject]@{
                PSTypeName   = 'ShowTree.TreeChildProvider'
                Name         = 'PowerShell'
                ProviderMode = 'PowerShell'
                GetChildren  = { }
            }

            $item = New-FixtureTreeItem `
                -Name 'file-a.txt' `
                -ParentPath $rootPath `
                -Depth 0

            $record = New-TreeRecord `
                -RecordType Item `
                -TreeItem $item `
                -TreeLayout (New-TreeLayout -Depth 0 -RelativeDepth 0 -IsLastSibling:$true)

            Mock Resolve-Path {
                [PSCustomObject]@{
                    ProviderPath = $rootPath
                    Path = $rootPath
                }
            }

            Mock New-TreeChildProvider {
                $provider
            }

            Mock Invoke-TreeTraversal {
                $record
            }

            $records = @(Get-TreeItem -Path $rootPath -Depth 0)

            $records.Count | Should -Be 1
            $records[0].PSTypeNames | Should -Contain 'ShowTree.TreeRecord'
            $records[0].TreeItem.Name | Should -Be 'file-a.txt'

            Should -Invoke New-TreeChildProvider -Times 1 -Exactly -ParameterFilter {
                $ProviderMode -eq 'PowerShell'
            }

            Should -Invoke Invoke-TreeTraversal -Times 1 -Exactly -ParameterFilter {
                $Path -eq $rootPath -and
                        $RootPath -eq $rootPath -and
                        $MaxDepth -eq 0 -and
                        $CurrentDepth -eq 0 -and
                        $Provider -eq $provider
            }
        }
    }

    It 'uses unresolved path text when Resolve-Path does not resolve the path' {
        InModuleScope ShowTree {
            $path = $IsWindows ? 'C:\MissingRoot' : '/missing-root'

            $provider = [PSCustomObject]@{
                PSTypeName   = 'ShowTree.TreeChildProvider'
                Name         = 'PowerShell'
                ProviderMode = 'PowerShell'
                GetChildren  = { }
            }

            Mock Resolve-Path { $null }

            Mock New-TreeChildProvider {
                $provider
            }

            Mock Invoke-TreeTraversal {
                return
            }

            $records = @(Get-TreeItem -Path $path -Depth 0)

            $records | Should -BeNullOrEmpty

            Should -Invoke Invoke-TreeTraversal -Times 1 -Exactly -ParameterFilter {
                $Path -eq $path -and
                        $RootPath -eq $path
            }
        }
    }

    It 'passes ProviderMode to New-TreeChildProvider' {
        InModuleScope ShowTree {
            $rootPath = $IsWindows ? 'C:\Root' : '/root'

            $provider = [PSCustomObject]@{
                PSTypeName   = 'ShowTree.TreeChildProvider'
                Name         = 'Win32'
                ProviderMode = 'Win32'
                GetChildren  = { }
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

            Mock Invoke-TreeTraversal {
                return
            }

            $records = @(Get-TreeItem -Path $rootPath -ProviderMode Win32)

            $records | Should -BeNullOrEmpty

            Should -Invoke New-TreeChildProvider -Times 1 -Exactly -ParameterFilter {
                $ProviderMode -eq 'Win32'
            }

            Should -Invoke Invoke-TreeTraversal -Times 1 -Exactly -ParameterFilter {
                $Provider -eq $provider
            }
        }
    }

    It 'passes filtering switches to Invoke-TreeTraversal' {
        InModuleScope ShowTree {
            $rootPath = $IsWindows ? 'C:\Root' : '/root'

            $provider = [PSCustomObject]@{
                PSTypeName   = 'ShowTree.TreeChildProvider'
                Name         = 'PowerShell'
                ProviderMode = 'PowerShell'
                GetChildren  = { }
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

            Mock Invoke-TreeTraversal {
                return
            }

            $records = @(
                Get-TreeItem `
                    -Path $rootPath `
                    -Depth 3 `
                    -Include '*.ps1' `
                    -Exclude 'bin' `
                    -HideHidden `
                    -HideSystem `
                    -DirectoryOnly `
                    -FollowLinks
            )

            $records | Should -BeNullOrEmpty

            Should -Invoke Invoke-TreeTraversal -Times 1 -Exactly -ParameterFilter {
                $Path -eq $rootPath -and
                $RootPath -eq $rootPath -and
                $MaxDepth -eq 2 -and
                $CurrentDepth -eq 0 -and
                $Provider -eq $provider -and
                $Include -contains '*.ps1' -and
                $Exclude -contains 'bin' -and
                $HideHidden -eq $true -and
                $HideSystem -eq $true -and
                $DirectoryOnly -eq $true -and
                $FollowLinks -eq $true
            }
        }
    }

    It 'streams multiple TreeRecord objects from traversal' {
        InModuleScope ShowTree -Parameters @{ FixtureScripts = $script:FixtureScripts } {
            param([string[]] $FixtureScripts)
            foreach ($script in $FixtureScripts) { . $script }

            $rootPath = $IsWindows ? 'C:\Root' : '/root'

            $provider = [PSCustomObject]@{
                PSTypeName   = 'ShowTree.TreeChildProvider'
                Name         = 'PowerShell'
                ProviderMode = 'PowerShell'
                GetChildren  = { }
            }

            $file = New-FixtureTreeItem `
                -Name 'file-a.txt' `
                -ParentPath $rootPath `
                -Depth 0

            $dir = New-FixtureTreeItem `
                -Name 'dir-a' `
                -ParentPath $rootPath `
                -Metadata @{ IsContainer = $true } `
                -Depth 0

            $recordsToReturn = @(
                New-TreeRecord `
                    -RecordType Item `
                    -TreeItem $file `
                    -TreeLayout (New-TreeLayout -Depth 0 -RelativeDepth 0 -IsLastSibling:$false)

                New-TreeRecord `
                    -RecordType Item `
                    -TreeItem $dir `
                    -TreeLayout (New-TreeLayout -Depth 0 -RelativeDepth 0 -IsLastSibling:$true)
            )

            Mock Resolve-Path {
                [PSCustomObject]@{
                    ProviderPath = $rootPath
                    Path = $rootPath
                }
            }

            Mock New-TreeChildProvider {
                $provider
            }

            Mock Invoke-TreeTraversal {
                foreach ($record in $recordsToReturn) {
                    $record
                }
            }

            $records = @(Get-TreeItem -Path $rootPath -Depth 0)

            $records.Count | Should -Be 2
            $records.RecordType | Should -Be @('Item', 'Item')
            $records.TreeItem.Name | Should -Be @('file-a.txt', 'dir-a')
        }
    }
}
