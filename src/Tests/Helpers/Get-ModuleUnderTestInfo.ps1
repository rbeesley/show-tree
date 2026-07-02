# src/Tests/Helpers/Get-ModuleUnderTestInfo.ps1

[CmdletBinding()]
param(
    [string] $StartPath = $PSScriptRoot,
    [string] $ManifestPath,
    [string] $ModuleName,
    [string] $SourceRootName,
    [string] $SourceRootPath
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$helpersPath = Split-Path -Parent $PSCommandPath

$findManifestParams = @{}

if ($PSBoundParameters.ContainsKey('ManifestPath') -and -not [string]::IsNullOrWhiteSpace($ManifestPath)) {
    $findManifestParams.ManifestPath = $ManifestPath
}
else {
    $findManifestParams.StartPath = $StartPath
}

if ($PSBoundParameters.ContainsKey('ModuleName') -and -not [string]::IsNullOrWhiteSpace($ModuleName)) {
    $findManifestParams.ModuleName = $ModuleName
}

$resolvedManifestPath = . (Join-Path $helpersPath 'Find-ModuleManifest.ps1') @findManifestParams

$manifestData = Import-PowerShellDataFile -LiteralPath $resolvedManifestPath
$moduleBase   = Split-Path -Parent $resolvedManifestPath
$resolvedName = if (-not [string]::IsNullOrWhiteSpace($ModuleName)) {
    $ModuleName
}
else {
    [IO.Path]::GetFileNameWithoutExtension($resolvedManifestPath)
}

$rootModule = $manifestData.RootModule
if ([string]::IsNullOrWhiteSpace($rootModule)) {
    throw "Manifest '$resolvedManifestPath' does not define RootModule."
}

$rootModuleCandidate = Join-Path $moduleBase $rootModule
if (-not (Test-Path -LiteralPath $rootModuleCandidate -PathType Leaf)) {
    throw "RootModule '$rootModule' from manifest '$resolvedManifestPath' was not found at '$rootModuleCandidate'."
}

$resolvedRootModulePath = (Resolve-Path -LiteralPath $rootModuleCandidate).ProviderPath

$resolvedSourceRootPath = $null
$resolvedSourceRootName = $null

if ($PSBoundParameters.ContainsKey('SourceRootPath') -and -not [string]::IsNullOrWhiteSpace($SourceRootPath)) {
    if (-not (Test-Path -LiteralPath $SourceRootPath -PathType Container)) {
        throw "SourceRootPath '$SourceRootPath' does not exist or is not a directory."
    }

    $resolvedSourceRootPath = (Resolve-Path -LiteralPath $SourceRootPath).ProviderPath
    $resolvedSourceRootName = Split-Path -Leaf $resolvedSourceRootPath
}
elseif ($PSBoundParameters.ContainsKey('SourceRootName') -and -not [string]::IsNullOrWhiteSpace($SourceRootName)) {
    $candidateSourceRoot = Join-Path $moduleBase $SourceRootName

    if (-not (Test-Path -LiteralPath $candidateSourceRoot -PathType Container)) {
        throw "SourceRootName '$SourceRootName' resolved to '$candidateSourceRoot', but that directory does not exist."
    }

    $resolvedSourceRootPath = (Resolve-Path -LiteralPath $candidateSourceRoot).ProviderPath
    $resolvedSourceRootName = $SourceRootName
}
else {
    $resolvedSourceRootPath = $moduleBase
    $resolvedSourceRootName = Split-Path -Leaf $moduleBase
}

[pscustomobject]@{
    ModuleName      = $resolvedName
    ManifestPath    = $resolvedManifestPath
    ModuleBase      = $moduleBase
    RootModule      = $rootModule
    RootModulePath  = $resolvedRootModulePath
    SourceRootName  = $resolvedSourceRootName
    SourceRootPath  = $resolvedSourceRootPath
    ManifestData    = $manifestData
}
