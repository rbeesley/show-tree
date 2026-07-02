# src/Tests/Unit/Enumeration/New-TreeLayout.Tests.ps1

BeforeAll {
    $script:TestRoot = Resolve-Path "$PSScriptRoot\..\.."
    $script:ModuleUnderTest = . "$script:TestRoot\Helpers\Import-ModuleUnderTest.ps1" `
        -StartPath $PSScriptRoot `
        -ModuleName 'ShowTree' `
        -SourceRootName 'src' `
        -Exclude 'src/Tests/*' `
        -PassThru
}

Describe 'New-TreeLayout' {
    It 'creates a ShowTree.TreeLayout object with defaults' {
        InModuleScope ShowTree {
            $layout = New-TreeLayout

            $layout.PSTypeNames | Should -Contain 'ShowTree.TreeLayout'
            $layout.Depth | Should -Be 0
            $layout.RelativeDepth | Should -Be 0
            $layout.IsLastSibling | Should -BeFalse
            $layout.AncestorIsLastSibling | Should -Be @()
            $layout.HasLaterSiblingDirectory | Should -BeFalse
        }
    }

    It 'uses Depth as RelativeDepth by default' {
        InModuleScope ShowTree {
            $layout = New-TreeLayout -Depth 3

            $layout.Depth | Should -Be 3
            $layout.RelativeDepth | Should -Be 3
        }
    }

    It 'allows RelativeDepth to differ from Depth' {
        InModuleScope ShowTree {
            $layout = New-TreeLayout -Depth 4 -RelativeDepth 2

            $layout.Depth | Should -Be 4
            $layout.RelativeDepth | Should -Be 2
        }
    }

    It 'stores sibling and ancestor layout state' {
        InModuleScope ShowTree {
            $layout = New-TreeLayout `
                -Depth 3 `
                -RelativeDepth 2 `
                -IsLastSibling:$true `
                -AncestorIsLastSibling @($false, $true) `
                -HasLaterSiblingDirectory:$true

            $layout.IsLastSibling | Should -BeTrue
            $layout.AncestorIsLastSibling | Should -Be @($false, $true)
            $layout.HasLaterSiblingDirectory | Should -BeTrue
        }
    }

    It 'normalizes ancestor state to an array' {
        InModuleScope ShowTree {
            $layout = New-TreeLayout -AncestorIsLastSibling $true

            $layout.AncestorIsLastSibling.Count | Should -Be 1
            $layout.AncestorIsLastSibling[0] | Should -BeTrue
        }
    }
}
