# build/tasks.build.ps1

param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$moduleRoot = Split-Path $PSScriptRoot -Parent
$moduleSrcRoot = Join-Path $moduleRoot 'src'
$manifestPath = Join-Path $moduleRoot 'ShowTree.psd1'
$publicPath   = Join-Path $moduleSrcRoot 'Public'

task DiscoverPublicFunctions {
    $script:PublicFunctions = `
        Get-ChildItem -Path $publicPath `
            -Recurse `
            -Filter *.ps1 `
            -File `
            -PipelineVariable file `
            | ForEach-Object {
                $ast = [System.Management.Automation.Language.Parser]::ParseFile( `
                $file.FullName, `
                    [ref] $null, `
                    [ref] $null)
                if ($ast.EndBlock.Statements.Name) {
                    $ast.EndBlock.Statements.Name
                }
            }
}

task UpdateManifest DiscoverPublicFunctions, {
    Update-ModuleManifest -Path $manifestPath `
        -FunctionsToExport $script:PublicFunctions `
        -CmdletsToExport @() `
        -AliasesToExport @()
}

task ValidateManifest {
    Test-ModuleManifest -Path $manifestPath | Out-Null
}

task Test ValidateManifest, {
    Invoke-Pester -Path (Join-Path $moduleSrcRoot 'Tests') -Output Detailed
}

task default Test
