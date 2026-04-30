# ShowTree\Tests\Private\Resolve-TreePath.Tests.ps1

InModuleScope ShowTree {

    Describe "Resolve-TreePath" {

        It "Resolves relative path resolution" {
            Resolve-TreePath -Path '.' |
                Should -Be (Get-Location).ProviderPath
        }

        It "Resolves relative child path" {
            $temp = Join-Path (Get-Location) 'foo'
            New-Item -ItemType Directory -Path $temp -Force | Out-Null

            Resolve-TreePath -Path '.\foo' |
                Should -Be $temp

            Remove-Item $temp -Recurse -Force
        }

        It "Resolves absolute path" {
            Resolve-TreePath -Path 'C:\Windows' |
                Should -Be 'C:\Windows'
        }

        It "Returns nonexistent path (PowerShell mode)" {
            Resolve-TreePath -Path 'C:\Nope' |
                Should -BeNullOrEmpty
        }

        It "Returns nonexistent path (Tree mode)" {
            Resolve-TreePath -Path 'C:\Nope' -Mode 'Tree' |
                Should -Be 'C:\Nope'
        }

        It "Handles normalization" {
            Resolve-TreePath -Path 'c:\windows\..\windows\system32' |
                Should -Be 'C:\windows\system32'
        }
    }
}

Describe "Resolve-TreePath" {
    It "resolves '.' relative to the current working directory" {
        . .\ShowTree\Private\PathUtilities.ps1

        Push-Location $env:TEMP
        try {
            $expected = (Get-Location).ProviderPath
            Resolve-TreePath "." | 
                Should -Be $expected
        }
        finally {
            Pop-Location
        }
    }
}

Describe "Show-Tree path resolution" {

    It "uses the caller's working directory, not the module directory" {

        Push-Location $env:TEMP
        try {
            # Force a fresh import *after* changing location
            Remove-Module ShowTree -ErrorAction SilentlyContinue
            Import-Module (Join-Path $PSScriptRoot "../../ShowTree.psd1") -Force

            $result = Show-Tree "." -List -Depth 0

            $result[0] |
                Should -Match ([regex]::Escape((Get-Location).ProviderPath))
        }
        finally {
            Pop-Location
        }
    }
}
