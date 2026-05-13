# src\Tests\Helpers\Find-ModuleManifest.ps1

[CmdletBinding(DefaultParameterSetName = 'ByStartPath')]
param(
    [Parameter(ParameterSetName = 'ByStartPath')]
    [string] $StartPath = $PSScriptRoot,
    [Parameter(ParameterSetName = 'ByManifestPath', Mandatory)]
    [string] $ManifestPath,
    [string] $ModuleName
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

if ($PSCmdlet.ParameterSetName -eq 'ByManifestPath') {
    if (-not (Test-Path -LiteralPath $ManifestPath -PathType Leaf)) {
        throw "Manifest path '$ManifestPath' was not found."
    }

    return (Resolve-Path -LiteralPath $ManifestPath).ProviderPath
}

$cursor = $StartPath

if (Test-Path -LiteralPath $cursor -PathType Leaf) {
    $cursor = Split-Path -Parent $cursor
}

while ($cursor) {
    $manifests = Get-ChildItem -LiteralPath $cursor -Filter *.psd1 -File -ErrorAction SilentlyContinue |
        Sort-Object Name

    if ($ModuleName) {
        $manifests = $manifests | Where-Object BaseName -eq $ModuleName
    }

    $manifest = $manifests | Select-Object -First 1
    if ($manifest) {
        return $manifest.FullName
    }

    $parent = Split-Path -Parent $cursor
    if (-not $parent -or $parent -eq $cursor) {
        break
    }

    $cursor = $parent
}

$target = if ($ModuleName) { "module manifest for '$ModuleName'" } else { 'module manifest (*.psd1)' }
throw "Could not locate $target starting from '$StartPath'."
