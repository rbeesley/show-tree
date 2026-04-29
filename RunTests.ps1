# ShowTree\Tests\RunTests.ps1

$RepoRoot   = Split-Path -Parent $PSCommandPath
$ModuleRoot = Join-Path $RepoRoot 'ShowTree'
$TestsRoot  = Join-Path $ModuleRoot 'Tests'
$Manifest   = Join-Path $ModuleRoot 'ShowTree.psd1'

$config = @{
    Run = @{
        Path = $TestsRoot
    }
    Output = @{
        Verbosity = 'Detailed'
    }
    BeforeDiscovery = {
        Import-Module $using:Manifest -Force
    }
}

Invoke-Pester -Configuration $config