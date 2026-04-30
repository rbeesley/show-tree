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