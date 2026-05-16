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
            $tempPath = [System.IO.Path]::GetTempPath()
            Push-Location $tempPath
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
            $tempPath = [System.IO.Path]::GetTempPath()
            Push-Location $tempPath
            try {
                $temp = Join-Path (Get-Location).ProviderPath 'foo'
                if (-not (Test-Path $temp)) {
                    New-Item -ItemType Directory -Path $temp -Force | Out-Null
                }

                Resolve-TreePath -Path '.\foo' |
                    Should -Be $temp
            }
            finally {
                $temp = Join-Path $tempPath 'foo'
                if (Test-Path $temp) {
                    Remove-Item $temp -Recurse -Force
                }
                Pop-Location
            }
        }
    }

    It 'resolves absolute paths' {
        InModuleScope ShowTree {
            $absPath = if ($IsWindows) { 'C:\Windows' } else { '/etc' }
            Resolve-TreePath -Path $absPath |
                    Should -Be $absPath
        }
    }

    It 'writes an ItemNotFound-style error and returns null for nonexistent paths in PowerShell mode' {
        InModuleScope ShowTree {
            $errors = $null
            $nope = if ($IsWindows) { 'C:\Nope' } else { '/Nope' }

            $result = Resolve-TreePath -Path $nope -ErrorAction SilentlyContinue -ErrorVariable errors

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
            $itemNotFound[0].TargetObject | Should -Be $nope
        }
    }

    It 'returns the original path for nonexistent paths in Tree mode' {
        InModuleScope ShowTree {
            $nope = if ($IsWindows) { 'C:\Nope' } else { '/Nope' }
            Resolve-TreePath -Path $nope -Mode 'Tree' |
                Should -Be $nope
        }
    }

    It 'normalizes paths' {
        InModuleScope ShowTree {
            if ($IsWindows) {
                Resolve-TreePath -Path 'c:\windows\..\windows\system32' |
                    Should -Be 'C:\Windows\System32'
            }
            else {
                # Linux is case-sensitive, so we can't easily test normalization of casing
                # unless we know a specific path that exists with different casing in input.
                # But we can test segment collapse.
                Resolve-TreePath -Path '/etc/../etc/pam.d' |
                    Should -Be '/etc/pam.d'
            }
        }
    }
}

Describe 'Show-Tree path resolution' {
    It "uses the caller's working directory, not the module directory" {
        InModuleScope ShowTree {
            $tempPath = [System.IO.Path]::GetTempPath()
            Push-Location $tempPath
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
