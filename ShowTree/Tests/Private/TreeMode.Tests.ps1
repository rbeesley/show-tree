# ShowTree\Tests\Private\TreeMode.Tests.ps1

InModuleScope ShowTree {

    BeforeAll {
        . "$PSScriptRoot/PrivateHelpers.ps1"
    }

    Describe "Tree.com compatibility" {

        It "Matches Tree.com output for a simple tree" {
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

            $result = Show-TreeInternal -Path $fixture.FullName -Tree -IncludeFiles:$true | Out-String

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
