# ShowTree\Tests\Pester.psd1

@{
    Run = @{
        Path = 'Tests'
    }

    Output = @{
        Verbosity = 'Detailed'
    }

    # Import the module ONCE before any tests run
    BeforeDiscovery = {
        Import-Module "$PSScriptRoot/../ShowTree.psd1" -Force
    }
}
