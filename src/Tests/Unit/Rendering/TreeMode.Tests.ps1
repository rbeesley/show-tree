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
        $script:GapState = [PSCustomObject]@{
            LastGapMode = [GapMode]::None
        }
    }
}

Describe "Tree.com compatibility" {
    It "Matches Tree.com output for a simple tree" {
        InModuleScope ShowTree {
            . "$PSScriptRoot\..\..\Helpers\PrivateHelpers.ps1"

            $fixture = New-TestTree ([ordered]@{
                root = [ordered]@{
                    a = [ordered]@{
                        a1 = $null
                        a2 = $null
                    }
                    b = [ordered]@{
                        b1 = $null
                    }
                }
            })

            Mock Get-RawDirectoryEntries {
                param($Path)
                Convert-TestTreeToRaw -Root $fixture -Path $Path
            }

            $result = Show-TreeInternal -Path $fixture.FullName -Mode 'Tree' -IncludeFiles:$true | Out-String

            $expected = @"
├───a
│       a1
│       a2
└───b
        b1
"@.Trim()

            $result.Trim() | Should -Be $expected
        }
    }
}
