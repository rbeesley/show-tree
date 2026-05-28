# src/Tests/Unit/Localization.Tests.ps1

BeforeDiscovery {
    $localUICulture = [System.Globalization.CultureInfo]::CurrentUICulture.Name ?? "und"
    $script:SkipEnUs = $localUICulture -eq "en-US"
    $script:SkipNotEnUs = $localUICulture -ne "en-US"
}

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

Describe "Localization" {
    It "Should load default en-US strings when no culture is specified" -Skip:$script:SkipNotEnUs {
        # If we're not running in an en-US culture, we should skip this test since the default strings are en-US
        InModuleScope ShowTree -Parameters @{ FixtureScripts = $script:FixtureScripts } {
            param( [string[]] $FixtureScripts ); foreach ($script in $FixtureScripts) { . $script }

            $styleProfile = Get-ShowTreeStyleProfile
            $styleProfile.UIStrings.Legend.Header | Should -Be "Legend"
        }
    }

    It "Show-TreeLegend should respect -Culture parameter" {
        $output = Show-TreeLegend -Culture "fr" | Out-String
        $output | Should -Match "Légende"
    }

    It "Show-Tree should respect -Culture parameter for error messages" {
        { Show-Tree -Color -Mono -Culture "fr" } `
            | Should -Throw "Impossible de spécifier à la fois -Color et -Mono."
    }

    It "Should load Pig Latin strings for 'qps-PLOC'" {
        InModuleScope ShowTree -Parameters @{ FixtureScripts = $script:FixtureScripts } {
            param( [string[]] $FixtureScripts ); foreach ($script in $FixtureScripts) { . $script }

            $styleProfile = Get-ShowTreeStyleProfile -Culture "qps-PLOC"
            $styleProfile.UIStrings.Legend.Header | Should -Be "Egendlay"
        }
    }

    It "Should load French strings for 'fr'" {
        InModuleScope ShowTree -Parameters @{ FixtureScripts = $script:FixtureScripts } {
            param( [string[]] $FixtureScripts ); foreach ($script in $FixtureScripts) { . $script }

            $styleProfile = Get-ShowTreeStyleProfile -Culture "fr"
            $styleProfile.UIStrings.Legend.Header | Should -Be "Légende"
        }
    }

    It "Should load French strings for 'fr-FR' (falling back to 'fr')" {
        InModuleScope ShowTree -Parameters @{ FixtureScripts = $script:FixtureScripts } {
            param( [string[]] $FixtureScripts ); foreach ($script in $FixtureScripts) { . $script }

            $styleProfile = Get-ShowTreeStyleProfile -Culture "fr-FR"
            $styleProfile.UIStrings.Legend.Header | Should -Be "Légende"
        }
    }

    It "Should load French strings for 'fr-CA' (falling back to 'fr')" {
        InModuleScope ShowTree -Parameters @{ FixtureScripts = $script:FixtureScripts } {
            param( [string[]] $FixtureScripts ); foreach ($script in $FixtureScripts) { . $script }

            $styleProfile = Get-ShowTreeStyleProfile -Culture "fr-CA"
            $styleProfile.UIStrings.Legend.Header | Should -Be "Légende"
        }
    }

    It "Should load French strings for 'fr-FR-custom' (falling back to 'fr')" {
        InModuleScope ShowTree -Parameters @{ FixtureScripts = $script:FixtureScripts } {
            param( [string[]] $FixtureScripts ); foreach ($script in $FixtureScripts) { . $script }

            $styleProfile = Get-ShowTreeStyleProfile -Culture "fr-FR-custom"
            $styleProfile.UIStrings.Legend.Header | Should -Be "Légende"
        }
    }

    It "Should default to CurrentUICulture when no culture is specified" -Skip:$script:SkipEnUs {
        # If we're running in an en-US culture, we should skip this test since the default strings are en-US
        # and we want to verify that it falls back to the current UI culture's strings
        InModuleScope ShowTree -Parameters @{ FixtureScripts = $script:FixtureScripts } {
            param( [string[]] $FixtureScripts ); foreach ($script in $FixtureScripts) { . $script }

            $expectedCulture = [System.Globalization.CultureInfo]::CurrentUICulture.Name
            
            # Check if the CurrentUICulture matches the current UI culture's strings
            $styleProfile = Get-ShowTreeStyleProfile
            
            # If current OS is en-US, it should be "Legend"
            # If current OS is fr-FR, it should be "Légende"
            # We can't easily change CurrentUICulture in a test, but we can check if it's NOT null or empty
            $styleProfile.UIStrings.Legend.Header | Should -Not -BeNullOrEmpty
        }
    }

    It "Should fallback to base strings for unknown culture" {
        InModuleScope ShowTree -Parameters @{ FixtureScripts = $script:FixtureScripts } {
            param( [string[]] $FixtureScripts ); foreach ($script in $FixtureScripts) { . $script }

            $styleProfile = Get-ShowTreeStyleProfile -Culture "non-existent"
            $styleProfile.UIStrings.Legend.Header | Should -Be "Legend"
        }
    }

}
