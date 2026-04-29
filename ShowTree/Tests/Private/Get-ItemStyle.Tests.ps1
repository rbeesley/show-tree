# ShowTree\Tests\Private\Get-ItemStyle.Tests.ps1

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
}