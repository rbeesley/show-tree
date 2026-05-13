# src\Tests\Private\Get-Connector.Tests.ps1

BeforeAll {
    $script:ModuleUnderTest = . "$PSScriptRoot\..\Helpers\Import-ModuleUnderTest.ps1" `
        -StartPath $PSScriptRoot `
        -ModuleName 'ShowTree' `
        -SourceRootName 'src' `
        -Exclude 'src/Tests/*' `
        -PassThru

    InModuleScope ShowTree {        
        # Define a style profile for testing
        $script:styleProfile = @{
            Base = @{
                File      = "1"
                Directory = "2"
                Symlink   = "3"
                Junction  = "4"
            }
            Attributes = @{
                None              = @{ Attributes = "1" }
                ReadOnly          = @{ Attributes = "2" }
                Hidden            = @{ Attributes = "4" }
                System            = @{
                    OverrideForeground = @{
                        File      = "1-8"
                        Directory = "2-8"
                    }
                }
                Directory         = @{ Attributes = "16" }
                Archive           = @{ Attributes = "32" }
                Device            = @{ Attributes = "64" }
                Normal            = @{ Attributes = "128" }
                Temporary         = @{ Attributes = "256" }
                SparseFile        = @{ Attributes = "512" }
                ReparsePoint      = @{ Attributes = "1024" }
                Compressed        = @{ Attributes = "2048" }
                Offline           = @{ Attributes = "4096" }
                NotContentIndexed = @{ Attributes = "8192" }
                Encrypted         = @{ Attributes = "16384" }
                IntegrityStream   = @{ Attributes = "32768" }
                NoScrubData       = @{ Attributes = "65536" }
            }
        }
    }
}

Describe "Get-ItemStyle" {
    It "Applies base directory style" {
        InModuleScope ShowTree {
            . "$PSScriptRoot\..\Helpers\PrivateHelpers.ps1"

            $item = New-TestItem -Name "Dir" -IsDirectory:$true -Attributes ([IO.FileAttributes]::Directory)
            $style = Get-ItemStyle -Item $item -Colorize:$true -StyleProfile $styleProfile
            $style.Name | Should -Be "Directory"
            $style.Ansi | Should -Match "2"   # Directory base code
        }
    }

    It "Applies Hidden overlay" {
        InModuleScope ShowTree {
            . "$PSScriptRoot\..\Helpers\PrivateHelpers.ps1"

            $item = New-TestItem -Name "Hidden" -Attributes ([IO.FileAttributes]::Hidden)
            $style = Get-ItemStyle -Item $item -Colorize:$true -StyleProfile $styleProfile
            $style.Name | Should -Be "File"   # Base type should still be File
            $style.Ansi | Should -Match "1"   # File base code
            $style.Ansi | Should -Match "4"   # Hidden attribute code
        }
    }

    It "Applies System foreground override" {
        InModuleScope ShowTree {
            . "$PSScriptRoot\..\Helpers\PrivateHelpers.ps1"

            $item = New-TestItem -Name "Sys" -Attributes ([IO.FileAttributes]::System)
            $style = Get-ItemStyle -Item $item -Colorize:$true -StyleProfile $styleProfile
            $style.Name | Should -Be "File"   # Base type should still be File
            $style.Ansi | Should -Match "1-8" # System file override
        }
    }
}

Describe "Get-Connector" {
    It "Returns Unicode directory connector (non-last)" {
        InModuleScope ShowTree {
            Get-Connector -Type Directory -IsLast:$false |
                Should -Be "╠══ "
        }
    }

    It "Returns Unicode directory connector (last)" {
        InModuleScope ShowTree {
            Get-Connector -Type Directory -IsLast:$true |
                Should -Be "╚══ "
        }
    }

    It "Returns ASCII connectors when -Ascii is used" {
        InModuleScope ShowTree {
            Get-Connector -Type File -Ascii |
                Should -Be "+-- "
        }
    }

    It "Returns Tree.com connectors in -Tree mode" {
        InModuleScope ShowTree {
            Get-Connector -Type Directory -Mode 'Tree' -IsLast:$false |
                Should -Be "├───"
        }
    }
}
