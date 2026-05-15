# src\Tests\Unit\PathUtilities\PathUtilities.Tests.ps1

BeforeAll {
    $script:ModuleUnderTest = . "$PSScriptRoot\..\..\Helpers\Import-ModuleUnderTest.ps1" `
        -StartPath $PSScriptRoot `
        -ModuleName 'ShowTree' `
        -SourceRootName 'src' `
        -Exclude 'src/Tests/*' `
        -PassThru
}

Describe 'Resolve-TreePath' {
    It 'resolves "." relative to the current working directory' {
        InModuleScope ShowTree {
            Push-Location $env:TEMP
            try {
                Resolve-TreePath -Path '.' |
                    Should -Be (Get-Location).ProviderPath
            }
            finally {
                Pop-Location
            }
        }
    }

    It 'resolves relative child paths' {
        InModuleScope ShowTree {
            Push-Location $env:TEMP
            try {
                $temp = Join-Path (Get-Location) 'foo'
                New-Item -ItemType Directory -Path $temp -Force | Out-Null

                Resolve-TreePath -Path '.\foo' |
                    Should -Be $temp
            }
            finally {
                if (Test-Path (Join-Path $env:TEMP 'foo')) {
                    Remove-Item (Join-Path $env:TEMP 'foo') -Recurse -Force
                }
                Pop-Location
            }
        }
    }

    It 'resolves absolute paths' {
        InModuleScope ShowTree {
            Resolve-TreePath -Path 'C:\Windows' |
                    Should -Be 'C:\Windows'
        }
    }

    It 'writes an ItemNotFound-style error and returns null for nonexistent paths in PowerShell mode' {
        InModuleScope ShowTree {
            $errors = $null

            $result = Resolve-TreePath -Path 'C:\Nope' -ErrorAction SilentlyContinue -ErrorVariable errors

            # Returned value contract
            $result | Should -BeNullOrEmpty

            # At least one error was written
            $errors | Should -Not -BeNullOrEmpty

            # Find the error we generate in the catch block
            $itemNotFound = $errors | Where-Object {
                $_.Exception -is [System.Management.Automation.ItemNotFoundException] -and
                $_.CategoryInfo.Category -eq [System.Management.Automation.ErrorCategory]::ObjectNotFound
            }

            $itemNotFound | Should -Not -BeNullOrEmpty
            $itemNotFound[0].TargetObject | Should -Be 'C:\Nope'
        }
    }

    It 'returns the original path for nonexistent paths in Tree mode' {
        InModuleScope ShowTree {
            Resolve-TreePath -Path 'C:\Nope' -Mode 'Tree' |
                Should -Be 'C:\Nope'
        }
    }

    It 'normalizes paths' {
        InModuleScope ShowTree {
            Resolve-TreePath -Path 'c:\windows\..\windows\system32' |
                Should -Be 'C:\windows\system32'
        }
    }
}

Describe 'Show-Tree path resolution' {
    It "uses the caller's working directory, not the module directory" {
        InModuleScope ShowTree {
            Push-Location $env:TEMP
            try {
                $result = Show-Tree '.' -List -Mono -Depth 0
                $result[0] | Should -Match ([regex]::Escape((Get-Location).ProviderPath))
            }
            finally {
                Pop-Location
            }
        }
    }
}
