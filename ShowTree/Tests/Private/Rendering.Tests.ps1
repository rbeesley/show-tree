# ShowTree\Tests\Private\Get-Connector.Tests.ps1

InModuleScope ShowTree {

    BeforeAll {
        . "$PSScriptRoot/PrivateHelpers.ps1"
    }

    Describe "Get-ItemStyle" {

        It "Applies base directory style" {
            $item = New-TestItem -Name "Dir" -IsDirectory:$true -Attributes ([IO.FileAttributes]::Directory)
            $style = Get-ItemStyle -Item $item -Colorize:$true
            $style.Name | Should -Be "Directory"
        }

        It "Applies Hidden overlay" {
            $item = New-TestItem -Name "Hidden" -Attributes ([IO.FileAttributes]::Hidden)
            $style = Get-ItemStyle -Item $item -Colorize:$true
            $style.Ansi | Should -Match "2"   # Hidden attribute code
        }

        It "Applies System foreground override" {
            $item = New-TestItem -Name "Sys" -Attributes ([IO.FileAttributes]::System)
            $style = Get-ItemStyle -Item $item -Colorize:$true
            $style.Ansi | Should -Match "31"  # System file override
        }
    }

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
            Get-Connector -Type Directory -Mode 'Tree' -IsLast:$false |
                Should -Be "├───"
        }
    }
}