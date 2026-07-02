# src/Tests/Unit/Rendering/Rendering.Tests.ps1

BeforeAll {
    $script:TestRoot = Resolve-Path "$PSScriptRoot\..\.."
    $script:ModuleUnderTest = . "$script:TestRoot\Helpers\Import-ModuleUnderTest.ps1" `
        -StartPath $PSScriptRoot `
        -ModuleName 'ShowTree' `
        -SourceRootName 'src' `
        -Exclude 'src/Tests/*' `
        -PassThru

    $script:FixtureScripts = @(
        "$script:TestRoot\Helpers\PrivateHelpers.ps1"
    )

    InModuleScope ShowTree {
        $script:realProfile = Get-ShowTreeStyleProfile

        $script:styleProfile = @{
            Base = @{
                File      = "31"
                Directory = "34"
            }
            States = @{
                Hidden     = @{ AnsiStyle = "2" }
                Executable = @{ AnsiStyle = "1" }
                Symlink    = @{ AnsiStyle = "4" }
                SetUid     = @{ Background = "41" }
                System     = @{
                    Foreground = @{
                        File      = "91"
                        Directory = "95"
                    }
                }
            }
        }
    }
}

Describe "Get-ItemStyle" {
    It "uses the file base style for files" {
        InModuleScope ShowTree -Parameters @{ FixtureScripts = $script:FixtureScripts } {
            param([string[]] $FixtureScripts)
            foreach ($script in $FixtureScripts) { . $script }

            $item = New-TreeItem -FullPath "file.txt" -IsContainer:$false -Kind "File"

            $style = Get-ItemStyle -Item $item -Colorize:$true -StyleProfile $styleProfile

            $style.Name | Should -Be "File"
            $style.Ansi | Should -Match "\[31m"
        }
    }

    It "uses the directory base style for directories" {
        InModuleScope ShowTree -Parameters @{ FixtureScripts = $script:FixtureScripts } {
            param([string[]] $FixtureScripts)
            foreach ($script in $FixtureScripts) { . $script }

            $item = New-TreeItem -FullPath "dir" -IsContainer:$true -Kind "Directory"

            $style = Get-ItemStyle -Item $item -Colorize:$true -StyleProfile $styleProfile

            $style.Name | Should -Be "Directory"
            $style.Ansi | Should -Match "\[34m"
        }
    }

    It "returns no ANSI sequence when colorization is disabled" {
        InModuleScope ShowTree -Parameters @{ FixtureScripts = $script:FixtureScripts } {
            param([string[]] $FixtureScripts)
            foreach ($script in $FixtureScripts) { . $script }

            $item = New-TreeItem -FullPath "file.txt" -IsContainer:$false -Kind "File" -States @("Hidden")

            $style = Get-ItemStyle -Item $item -Colorize:$false -StyleProfile $styleProfile

            $style.Name | Should -Be "File"
            $style.Ansi | Should -Be ""
        }
    }

    It "applies explicit state ANSI overlays" {
        InModuleScope ShowTree -Parameters @{ FixtureScripts = $script:FixtureScripts } {
            param([string[]] $FixtureScripts)
            foreach ($script in $FixtureScripts) { . $script }

            $item = New-TreeItem -FullPath "script.ps1" -IsContainer:$false -Kind "File" -States @(
                "Executable"
                "Symlink"
            )

            $style = Get-ItemStyle -Item $item -Colorize:$true -StyleProfile $styleProfile

            $style.Ansi | Should -Match "31"
            $style.Ansi | Should -Match "1"
            $style.Ansi | Should -Match "4"
        }
    }

    It "derives state overlays from native file attributes" {
        InModuleScope ShowTree -Parameters @{ FixtureScripts = $script:FixtureScripts } {
            param([string[]] $FixtureScripts)
            foreach ($script in $FixtureScripts) { . $script }

            $item = New-TreeItem -FullPath "hidden.txt" -IsContainer:$false -Kind "File"
            $item.Native = [PSCustomObject]@{
                Platform       = "Windows"
                FileAttributes = [IO.FileAttributes]::Hidden
            }

            $style = Get-ItemStyle -Item $item -Colorize:$true -StyleProfile $styleProfile

            $style.Ansi | Should -Match "31"
            $style.Ansi | Should -Match "2"
        }
    }

    It "applies foreground overrides for the current item type" {
        InModuleScope ShowTree -Parameters @{ FixtureScripts = $script:FixtureScripts } {
            param([string[]] $FixtureScripts)
            foreach ($script in $FixtureScripts) { . $script }

            $file = New-TreeItem -FullPath "system-file.txt" -IsContainer:$false -Kind "File" -States @("System")
            $directory = New-TreeItem -FullPath "system-dir" -IsContainer:$true -Kind "Directory" -States @("System")

            $fileStyle = Get-ItemStyle -Item $file -Colorize:$true -StyleProfile $styleProfile
            $directoryStyle = Get-ItemStyle -Item $directory -Colorize:$true -StyleProfile $styleProfile

            $fileStyle.Ansi | Should -Match "91"
            $fileStyle.Ansi | Should -Not -Match "31"

            $directoryStyle.Ansi | Should -Match "95"
            $directoryStyle.Ansi | Should -Not -Match "34"
        }
    }

    It "applies background overlays from semantic states" {
        InModuleScope ShowTree -Parameters @{ FixtureScripts = $script:FixtureScripts } {
            param([string[]] $FixtureScripts)
            foreach ($script in $FixtureScripts) { . $script }

            $item = New-TreeItem -FullPath "setuid-file" -IsContainer:$false -Kind "File" -States @("SetUid")

            $style = Get-ItemStyle -Item $item -Colorize:$true -StyleProfile $styleProfile

            $style.Ansi | Should -Match "31"
            $style.Ansi | Should -Match "41"
        }
    }
}

Describe "Get-Connector" {
    It "returns the Unicode directory connector for a non-last item" {
        InModuleScope ShowTree -Parameters @{ FixtureScripts = $script:FixtureScripts } {
            param([string[]] $FixtureScripts)
            foreach ($script in $FixtureScripts) { . $script }

            Get-Connector -Type Directory -IsLast:$false -StyleProfile $realProfile |
                    Should -Be "╠══ "
        }
    }

    It "returns the Unicode directory connector for a last item" {
        InModuleScope ShowTree -Parameters @{ FixtureScripts = $script:FixtureScripts } {
            param([string[]] $FixtureScripts)
            foreach ($script in $FixtureScripts) { . $script }

            Get-Connector -Type Directory -IsLast:$true -StyleProfile $realProfile |
                    Should -Be "╚══ "
        }
    }

    It "returns ASCII connectors when ASCII mode is used" {
        InModuleScope ShowTree -Parameters @{ FixtureScripts = $script:FixtureScripts } {
            param([string[]] $FixtureScripts)
            foreach ($script in $FixtureScripts) { . $script }

            Get-Connector -Type File -Ascii -StyleProfile $realProfile |
                    Should -Be "+-- "
        }
    }

    It "returns Tree.com connectors in Tree mode" {
        InModuleScope ShowTree -Parameters @{ FixtureScripts = $script:FixtureScripts } {
            param([string[]] $FixtureScripts)
            foreach ($script in $FixtureScripts) { . $script }

            Get-Connector -Type Directory -Mode "Tree" -IsLast:$false -StyleProfile $realProfile |
                    Should -Be "├───"
        }
    }
}
