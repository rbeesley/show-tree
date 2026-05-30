# src/Tests/Unit/Legend.Tests.ps1

BeforeAll {
    $script:TestRoot = Resolve-Path "$PSScriptRoot\.."
    $script:ModuleUnderTest = . "$script:TestRoot\Helpers\Import-ModuleUnderTest.ps1" `
        -StartPath $PSScriptRoot `
        -ModuleName 'ShowTree' `
        -SourceRootName 'src' `
        -Exclude 'src/Tests/*' `
        -PassThru
    $script:FixtureScripts  = @()
}

Describe "Show-TreeLegend" {
    It "Filters states based on platform" {
        InModuleScope ShowTree -Parameters @{ FixtureScripts = $script:FixtureScripts } {
            param( [string[]] $FixtureScripts ); foreach ($script in $FixtureScripts) { . $script }

            $activeProfile = Get-ActiveShowTreeStyleProfile
            # Mock states to ensure we have both Windows and Unix specific states
            $activeProfile.States = @{
                'Hidden' = @{ AnsiStyle = '1' }
                'System' = @{ AnsiStyle = '2' }
                'Executable' = @{ AnsiStyle = '3' }
            }

            # Windows platform should show Hidden and System, but not Executable
            $winStates = Get-LegendStateNames -StyleProfile $activeProfile -Platform Windows
            $winStates | Should -Contain 'Hidden'
            $winStates | Should -Contain 'System'
            $winStates | Should -Not -Contain 'Executable'

            # Unix platform should show Hidden and Executable, but not System
            $unixStates = Get-LegendStateNames -StyleProfile $activeProfile -Platform Unix
            $unixStates | Should -Contain 'Hidden'
            $unixStates | Should -Contain 'Executable'
            $unixStates | Should -Not -Contain 'System'
        }
    }

    It "Shows all states when -All is used" {
        InModuleScope ShowTree -Parameters @{ FixtureScripts = $script:FixtureScripts } {
            param([string[]] $FixtureScripts); foreach ($script in $FixtureScripts)
            {
                . $script
            }
            $activeProfile = Get-ActiveShowTreeStyleProfile
            $activeProfile.States = @{
                'Hidden' = @{ }
                'System' = @{ }
                'Executable' = @{ }
                'Custom' = @{ }
            }

            $allStates = Get-LegendStateNames -StyleProfile $activeProfile -All
            $allStates.Count | Should -Be 4
            $allStates | Should -Contain 'Custom'
        }
    }
}

Describe "Show-Tree Legend Parameters" {
    It "Throws when -Platform is used without -Legend" {
        InModuleScope ShowTree {
            { Show-Tree -Platform Windows } | Should -Throw
        }
    }

    It "Does not throw when -Platform is used with -Legend" {
        InModuleScope ShowTree {
            # We mock Show-TreeLegend to avoid actual output
            Mock Show-TreeLegend { }
            { Show-Tree -Legend -Platform Windows } | Should -Not -Throw
        }
    }

    It "Uses LegendAll switch correctly" {
        InModuleScope ShowTree {
            Mock Show-TreeLegend { }
            Show-Tree -LegendAll
            Assert-MockCalled Show-TreeLegend -ParameterFilter { $All -eq $true }
        }
    }
}
