# ShowTree\Tests\Private\Get-Connector.Tests.ps1

InModuleScope ShowTree {

    Describe "Get-Connector" {

        It "Returns Unicode directory connector (non-last)" {
            Get-Connector -Type Directory -IsLast:$false |
                Should -Be "╠══ "
        }

        It "Returns Unicode directory connector (last)" {
            Get-Connector -Type Directory -IsLast:$true |
                Should -Be "╚══ "
        }

        It "Returns ASCII connectors when -Ascii is used" {
            Get-Connector -Type File -Ascii |
                Should -Be "+-- "
        }

        It "Returns Tree.com connectors in -Tree mode" {
            Get-Connector -Type Directory -Tree -IsLast:$false |
                Should -Be "├───"
        }
    }
}