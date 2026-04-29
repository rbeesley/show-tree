# ShowTree\Tests\Private\Private.Tests.ps1

# This helper lives in the test scope, not the module scope.
# It does NOT need to be visible inside the module.

InModuleScope ShowTree {

    BeforeAll {
        . "$PSScriptRoot/PrivateHelpers.ps1"
    }

    Describe "Private function smoke test" {

        It "Can call Get-Connector" {
            Get-Connector -Type Directory -IsLast:$false |
                Should -Be "╠══ "
        }

        It "Can call Get-FilteredTreeItems" {
            
            $items = @(
                New-TestItem -Name "a"
                New-TestItem -Name "b"
            )

            $result = Get-FilteredTreeItems -Items $items -Exclude "b"
            $result.Name | Should -Be @("a")
        }
    }
}
