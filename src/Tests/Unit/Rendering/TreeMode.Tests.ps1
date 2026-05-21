# src\Tests\Unit\Rendering\TreeMode.Tests.ps1

BeforeAll {
    $script:ModuleUnderTest = . "$PSScriptRoot\..\..\Helpers\Import-ModuleUnderTest.ps1" `
        -StartPath $PSScriptRoot `
        -ModuleName 'ShowTree' `
        -SourceRootName 'src' `
        -Exclude 'src/Tests/*' `
        -PassThru

    InModuleScope ShowTree {  
        # Initialize gap state machine
        $script:testStyleProfile = Get-ShowTreeStyleProfile
    }
}

Describe "Tree.com compatibility" -Skip:(-not $IsWindows) {
    It "Matches Tree.com output for a simple tree" {
        InModuleScope ShowTree {
            . (Join-Path $script:moduleSrcRoot "Tests\Fixtures\TreeItemFixtures.ps1")
            . (Join-Path $script:moduleSrcRoot "Tests\Helpers\PrivateHelpers.ps1")

            $structure = [ordered]@{
                a = [ordered]@{
                    a1 = $null
                    a2 = $null
                }
                b = [ordered]@{
                    b1 = $null
                }
            }
            
            $root = New-FixtureTree -Structure $structure

#            Mock Get-RawDirectoryEntries {
#                param($Path)
#                Convert-TestTreeToRaw -Root $fixture -Path $Path
#            }

            $items = $root | Select-TreeItem -Flatten

            $output = @($items | Format-Tree -Mode Tree)

            $output[0] | Should -Be "├───a"
            $output[1] | Should -Be "│       a1"
            $output[2] | Should -Be "│       a2"
            $output[3] | Should -Be "└───b"
            $output[4] | Should -Be "        b1"

            $output.Count | Should -Be 5
        }
    }
}
