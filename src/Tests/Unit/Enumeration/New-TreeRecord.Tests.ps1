# src/Tests/Unit/Enumeration/New-TreeRecord.Tests.ps1

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

Describe 'New-TreeRecord' {
    It 'creates an Item record' {
        InModuleScope ShowTree -Parameters @{ FixtureScripts = $script:FixtureScripts } {
            param([string[]] $FixtureScripts)
            foreach ($script in $FixtureScripts) { . $script }

            $rootPath = $IsWindows ? 'C:\Root' : '/root'
            $item = New-FixtureTreeItem `
                -Name 'file.txt' `
                -ParentPath $rootPath `
                -Depth 1

            $layout = New-TreeLayout `
                -Depth 1 `
                -RelativeDepth 1 `
                -IsLastSibling:$true

            $record = New-TreeRecord `
                -RecordType Item `
                -TreeItem $item `
                -TreeLayout $layout

            $record.PSTypeNames | Should -Contain 'ShowTree.TreeRecord'
            $record.RecordType | Should -Be 'Item'
            $record.TreeItem | Should -Be $item
            $record.TreeLayout | Should -Be $layout
        }
    }

    It 'creates a Gap record without an item' {
        InModuleScope ShowTree {
            $layout = New-TreeLayout `
                -Depth 1 `
                -RelativeDepth 1 `
                -AncestorIsLastSibling @($false)

            $record = New-TreeRecord `
                -RecordType Gap `
                -TreeLayout $layout

            $record.PSTypeNames | Should -Contain 'ShowTree.TreeRecord'
            $record.RecordType | Should -Be 'Gap'
            $record.TreeItem | Should -BeNullOrEmpty
            $record.TreeLayout | Should -Be $layout
        }
    }

    It 'throws when an Item record is missing TreeItem' {
        InModuleScope ShowTree {
            $layout = New-TreeLayout

            {
                New-TreeRecord `
                    -RecordType Item `
                    -TreeLayout $layout
            } | Should -Throw
        }
    }

    It 'throws when TreeLayout is not a ShowTree.TreeLayout object' {
        InModuleScope ShowTree {
            $layout = [PSCustomObject]@{
                Depth = 0
            }

            {
                New-TreeRecord `
                    -RecordType Gap `
                    -TreeLayout $layout
            } | Should -Throw
        }
    }
}
