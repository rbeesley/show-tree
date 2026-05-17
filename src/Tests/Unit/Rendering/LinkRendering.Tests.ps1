# src\Tests\Unit\Rendering\LinkRendering.Tests.ps1

BeforeAll {
    $script:ModuleUnderTest = . "$PSScriptRoot\..\..\Helpers\Import-ModuleUnderTest.ps1" `
        -StartPath $PSScriptRoot `
        -ModuleName 'ShowTree' `
        -SourceRootName 'src' `
        -Exclude 'src/Tests/*' `
        -PassThru
}

Describe "Link Target Rendering" {
    Context "Write-TreeItem" {
        BeforeEach {
            InModuleScope ShowTree {
                $script:GapState = [PSCustomObject]@{
                    LastGapMode = 'None'
                }
            }
        }

        It "renders a link target when ShowTargets is specified" {
            InModuleScope ShowTree {
                $targetPath = if ($IsWindows) { 'C:\Target' } else { '/tmp/target' }
                $linkPath = if ($IsWindows) { 'C:\Link' } else { '/tmp/link' }
                
                $link = [PSCustomObject]@{
                    Type       = 'SymbolicLink'
                    Target     = $targetPath
                    TargetPath = $targetPath
                    IsBroken   = $false
                }
                
                $item = New-TreeItem -FullPath $linkPath -Kind 'Symlink' -IsContainer $false -Link $link
                
                $output = Write-TreeItem -Item $item -Type File -ShowTargets -Colorize:$false
                
                $output | Should -Match "-> .*$([regex]::Escape($targetPath))"
            }
        }

        It "renders a link target using fallback when Link.Target is missing but item is a link" {
            # This tests the fallback logic in Write-TreeItem.ps1
            InModuleScope ShowTree {
                $tempDir = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), [System.Guid]::NewGuid().ToString())
                New-Item -ItemType Directory -Path $tempDir | Out-Null
                $targetFile = Join-Path $tempDir "Target.txt"
                "test" | Out-File $targetFile
                
                $linkFile = Join-Path $tempDir "Link.txt"
                
                try {
                    # Create a real link to test fallback
                    New-Item -ItemType SymbolicLink -Path $linkFile -Target $targetFile | Out-Null
                    
                    $item = New-TreeItem -FullPath $linkFile -Kind 'Symlink' -IsContainer $false
                    # Note: We didn't pass -Link, so item.IsLink will be false by default if Kind is just 'Symlink' 
                    # but doesn't have Link object. 
                    # Actually New-TreeItem sets isLink = $Link.Type -and $Link.Type -ne 'None'
                    
                    # We need to at least mark it as a link for Write-TreeItem to try resolution
                    $item.IsLink = $true
                    
                    $output = Write-TreeItem -Item $item -Type File -ShowTargets -Colorize:$false
                    $output | Should -Match "-> .*$([regex]::Escape($targetFile))"
                }
                finally {
                    if (Test-Path $tempDir) { Remove-Item $tempDir -Recurse -Force }
                }
            }
        }
    }

    Context "Show-TreeInternal" {
        It "populates link targets for symlinks" {
            InModuleScope ShowTree {
                $tempDir = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), [System.Guid]::NewGuid().ToString())
                New-Item -ItemType Directory -Path $tempDir | Out-Null
                $targetFile = Join-Path $tempDir "Target.txt"
                "test" | Out-File $targetFile
                
                $linkFile = Join-Path $tempDir "Link.txt"
                
                try {
                    New-Item -ItemType SymbolicLink -Path $linkFile -Target $targetFile | Out-Null
                    
                    # We need to mock Show-TreeInternal's recursive calls or just check its output
                    # But better check if it creates TreeItems with Link info
                    # Show-TreeInternal doesn't return items, it writes to output.
                    
                    $output = Show-TreeInternal -Path $tempDir -IncludeFiles -ShowTargets -Colorize:$false
                    $outputString = $output | Out-String
                    $outputString | Should -Match "Link.txt.*-> .*$([regex]::Escape($targetFile))"
                }
                finally {
                    if (Test-Path $tempDir) { Remove-Item $tempDir -Recurse -Force }
                }
            }
        }

        It "populates link targets for junctions" {
            if (-not $IsWindows) { return }
            InModuleScope ShowTree {
                $tempDir = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), [System.Guid]::NewGuid().ToString())
                New-Item -ItemType Directory -Path $tempDir | Out-Null
                $targetDir = Join-Path $tempDir "TargetDir"
                New-Item -ItemType Directory -Path $targetDir | Out-Null
                
                $linkDir = Join-Path $tempDir "LinkDir"
                
                try {
                    New-Item -ItemType Junction -Path $linkDir -Target $targetDir | Out-Null
                    
                    $output = Show-TreeInternal -Path $tempDir -ShowTargets -Colorize:$false
                    $outputString = $output | Out-String
                    $outputString | Should -Match "LinkDir.*-> .*$([regex]::Escape($targetDir))"
                }
                finally {
                    if (Test-Path $tempDir) { Remove-Item $tempDir -Recurse -Force }
                }
            }
        }
    }
}
