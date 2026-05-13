# Run-TestFile.ps1

param(
    [Parameter(Mandatory)]
    [string] $Path
)

$resolvedPath = (Resolve-Path $Path).ProviderPath

$config = New-PesterConfiguration
$config.Run.Path = $resolvedPath
$config.Output.Verbosity = 'Detailed'

Invoke-Pester -Configuration $config
