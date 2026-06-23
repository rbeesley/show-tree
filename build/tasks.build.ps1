# build/tasks.build.ps1

# Task Dependency Graph
# 
# graph TD
#    default --> Test
#
#    UpdateManifest --> DiscoverPublicFunctions --> ValidateManifest
#
#    ForceBuild --> Clean
#    ForceBuild --> UpdateManifest
#    ForceBuild --> BuildDist
#    ForceBuild -. body .-> SaveDistFingerprint[Save-DistFingerprint]
#
#    BuildIfNeeded -. if stale .-> Clean
#    BuildIfNeeded -. if stale .-> UpdateManifest
#    BuildIfNeeded -. if stale .-> BuildDist
#    BuildIfNeeded -. if stale .-> SaveDistFingerprint
#
#    Build --> BuildIfNeeded
#    Build -. if not current .-> ForceBuild
#
#    Test --> ValidateManifest
#
#    TestDist --> BuildIfNeeded
#    TestDesktop --> BuildIfNeeded
#
#    TestAll --> Test
#    TestAll --> TestDist
#    TestAll --> TestDesktop

param(
    [string[]] $Test,
    [string[]] $Tag
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$moduleRoot      = Split-Path $PSScriptRoot -Parent
$moduleSrcRoot   = Join-Path  $moduleRoot     'src'
$manifestPath    = Join-Path  $moduleRoot     'ShowTree.psd1'
$rootModulePath  = Join-Path  $moduleRoot     'ShowTree.psm1'
$publicPath      = Join-Path  $moduleSrcRoot  'Public'
$distPath        = Join-Path  $moduleRoot     'dist'
$buildCachePath  = Join-Path  $PSScriptRoot   '.cache'
$fingerprintPath = Join-Path $buildCachePath 'dist.fingerprint'

#
# Tasks
#

task default Test

task Build BuildIfNeeded, {
    if (-not (Test-DistIsCurrent)) {
        Invoke-Build ForceBuild
    }
}

task BuildDist DiscoverPublicFunctions, {
    $corePath = Join-Path $distPath 'Core'
    $desktopPath = Join-Path $distPath 'Desktop'

    New-Item -Path $corePath -ItemType Directory -Force | Out-Null
    New-Item -Path $desktopPath -ItemType Directory -Force | Out-Null

    $excludedRuntimeSourceDirectories = @(
        'Tests'
    )

    $runtimeSourceFiles = Get-ChildItem -Path $moduleSrcRoot -Recurse -File |
            Where-Object {
                $relativePath = $_.FullName.Substring($moduleSrcRoot.Length + 1)

                foreach ($excludedDirectory in $excludedRuntimeSourceDirectories) {
                    if ($relativePath -eq $excludedDirectory -or
                            $relativePath.StartsWith("$excludedDirectory\", [System.StringComparison]::OrdinalIgnoreCase) -or
                            $relativePath.StartsWith("$excludedDirectory/", [System.StringComparison]::OrdinalIgnoreCase)) {
                        return $false
                    }
                }

                return $true
            }

    # Copy source to Core
    foreach ($sourceFile in $runtimeSourceFiles) {
        $relativePath = $sourceFile.FullName.Substring($moduleSrcRoot.Length + 1)
        $destFile = Join-Path $corePath $relativePath
        $destDir = Split-Path $destFile -Parent

        if (-not (Test-Path $destDir)) {
            New-Item -Path $destDir -ItemType Directory -Force | Out-Null
        }

        Copy-Item -Path $sourceFile.FullName -Destination $destFile
    }

    Copy-Item -Path $rootModulePath -Destination (Join-Path $corePath 'ShowTree.psm1')

    # Write the public fuctions we are exporting
    Set-DistributionRootModuleExports `
        -Path (Join-Path $corePath 'ShowTree.psm1') `
        -FunctionsToExport $script:PublicFunctions

    # Copy source to Desktop and transpile
    foreach ($sourceFile in $runtimeSourceFiles) {
        $relativePath = $sourceFile.FullName.Substring($moduleSrcRoot.Length + 1)
        $destFile = Join-Path $desktopPath $relativePath
        $destDir = Split-Path $destFile -Parent

        if (-not (Test-Path $destDir)) {
            New-Item -Path $destDir -ItemType Directory -Force | Out-Null
        }

        if ($sourceFile.Extension -eq '.ps1' -or $sourceFile.Extension -eq '.psm1') {
            & (Join-Path $PSScriptRoot 'Transpile-Source.ps1') -SourcePath $sourceFile.FullName -DestinationPath $destFile
        }
        else {
            Copy-Item -Path $sourceFile.FullName -Destination $destFile
        }
    }

    & (Join-Path $PSScriptRoot 'Transpile-Source.ps1') -SourcePath $rootModulePath -DestinationPath (Join-Path $desktopPath 'ShowTree.psm1')

    # Write the public fuctions we are exporting
    Set-DistributionRootModuleExports `
        -Path (Join-Path $desktopPath 'ShowTree.psm1') `
        -FunctionsToExport $script:PublicFunctions
    
    # Copy manifest to dist root and update it to point to routing psm1
    $distManifestPath = Join-Path $distPath 'ShowTree.psd1'
    Copy-Item -Path $manifestPath -Destination $distManifestPath

    # RootModule is already 'ShowTree.psm1' in the original manifest, which is what we want for the dist root too.
    # We should ensure CompatiblePSEditions includes both Core and Desktop in the dist manifest.
    $manifestContent = Get-Content $distManifestPath -Raw
    $manifestContent = $manifestContent -replace "# CompatiblePSEditions = @\(\)", "CompatiblePSEditions = @('Core', 'Desktop')"
    $manifestContent | Set-Content $distManifestPath -Encoding UTF8

    # Copy manifests to subdirectories and update CompatiblePSEditions
    $coreManifestPath = Join-Path $corePath 'ShowTree.psd1'
    Copy-Item -Path $manifestPath -Destination $coreManifestPath
    $coreManifestContent = Get-Content $coreManifestPath -Raw
    $coreManifestContent = $coreManifestContent -replace "# CompatiblePSEditions = @\(\)", "CompatiblePSEditions = @('Core')"
    $coreManifestContent | Set-Content $coreManifestPath -Encoding UTF8

    $desktopManifestPath = Join-Path $desktopPath 'ShowTree.psd1'
    Copy-Item -Path $manifestPath -Destination $desktopManifestPath
    $desktopManifestContent = Get-Content $desktopManifestPath -Raw
    $desktopManifestContent = $desktopManifestContent -replace "# CompatiblePSEditions = @\(\)", "CompatiblePSEditions = @('Desktop')"
    $desktopManifestContent | Set-Content $desktopManifestPath -Encoding UTF8

    # Create routing psm1 in dist root
    $routingContent = @'
if ($PSEdition -eq 'Core') {
    $path = Join-Path $PSScriptRoot 'Core\ShowTree.psd1'
}
else {
    $path = Join-Path $PSScriptRoot 'Desktop\ShowTree.psd1'
}
Import-Module -Name $path -Global
'@
    $routingContent | Set-Content (Join-Path $distPath 'ShowTree.psm1') -Encoding UTF8

    # Copy CHANGELOG.md, LICENSE, and README.md to dist root
    Copy-Item -Path (Join-Path $moduleRoot 'CHANGELOG.md') -Destination $distPath
    Copy-Item -Path (Join-Path $moduleRoot 'LICENSE') -Destination $distPath
    Copy-Item -Path (Join-Path $moduleRoot 'README.md') -Destination $distPath
}

task BuildIfNeeded {
    if (Test-DistIsCurrent) {
        Write-Host "dist is current; skipping build." -ForegroundColor DarkGray
        return
    }

    Write-Host "dist is stale; rebuilding." -ForegroundColor Cyan
    Invoke-Build Clean, UpdateManifest, BuildDist
    Save-DistFingerprint
}

task Clean {
    if (Test-Path $distPath) {
        Remove-Item $distPath -Recurse -Force
    }
}

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

task ForceBuild Clean, UpdateManifest, BuildDist, {
    Save-DistFingerprint
}

task Test ValidateManifest, {
    $testsDir = Join-Path $moduleSrcRoot 'Tests'
    $pesterConfigPath = Join-Path $testsDir 'Pester.psd1'
    
    $config = if (Test-Path $pesterConfigPath) {
        Import-PowerShellDataFile $pesterConfigPath
    } else {
        New-PesterConfiguration
    }

    # Ensure $config is a PesterConfiguration object if we want to use dot notation safely 
    # for properties that might not exist in the hash from PSD1
    if ($config -isnot [PesterConfiguration]) {
        $pesterConfig = New-PesterConfiguration
        foreach ($key in $config.Keys) {
            if ($pesterConfig.$key) {
                foreach ($subKey in $config.$key.Keys) {
                    $pesterConfig.$key.$subKey = $config.$key.$subKey
                }
            }
        }
        $config = $pesterConfig
    }

    # If $Test is provided, we need to resolve paths
    if ($Test) {
        $testPaths = foreach ($t in $Test) {
            # 1. Check if it's a full path
            if (Test-Path $t) {
                $t
            }
            # 2. Check if it's relative to Tests directory
            elseif (Test-Path (Join-Path $testsDir $t)) {
                Join-Path $testsDir $t
            }
            # 3. Search for files matching the name in Tests directory
            else {
                $found = Get-ChildItem -Path $testsDir -Filter "*$t*" -Recurse -File
                if ($found) {
                    $found.FullName
                } else {
                    Write-Warning "Could not find any tests matching '$t' in $testsDir"
                }
            }
        }
        if ($testPaths) {
            $config.Run.Path = $testPaths
        }
    } else {
        $config.Run.Path = $testsDir
    }

    if ($Tag) {
        $config.Filter.Tag = $Tag
    }

    $config.Output.Verbosity = 'Detailed'

    Invoke-Pester -Configuration $config
}

task TestAll Test, TestDist, TestDesktop, {
    # Full source tests + dist smoke tests
}

task TestDesktop BuildIfNeeded, {
    if ($PSVersionTable.PSEdition -eq 'Core' -and -not $IsWindows) {
        Write-Host "Skipping Windows PowerShell smoke test on non-Windows platform." -ForegroundColor Yellow
        return
    }

    $powershellExe = Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe'

    if (-not (Test-Path -LiteralPath $powershellExe)) {
        Write-Host "Skipping Windows PowerShell smoke test because powershell.exe was not found." -ForegroundColor Yellow
        return
    }

    $smokeTestPath = Join-Path $PSScriptRoot 'Test-WindowsPowerShellDist.ps1'
    $distManifestPath = Join-Path $distPath 'ShowTree.psd1'

    & $powershellExe `
        -NoLogo `
        -NoProfile `
        -ExecutionPolicy Bypass `
        -File $smokeTestPath `
        -DistManifestPath $distManifestPath

    if ($LASTEXITCODE -ne 0) {
        throw "Windows PowerShell dist smoke test failed with exit code $LASTEXITCODE."
    }
}

task TestDist BuildIfNeeded, {
    $distManifestPath = Join-Path $distPath 'ShowTree.psd1'

    Import-Module -Name $distManifestPath -Force -ErrorAction Stop

    try {
        Get-Command -Name Show-Tree -ErrorAction Stop | Out-Null

        $output = Show-Tree -Path $distPath -NoFiles -Mono | Out-String
        if ([string]::IsNullOrWhiteSpace($output)) {
            throw "Show-Tree dist smoke test produced no output."
        }

        Write-Host "PowerShell Core dist smoke test passed." -ForegroundColor Green
    }
    finally {
        Remove-Module ShowTree -Force -ErrorAction SilentlyContinue
    }
}

task UpdateManifest DiscoverPublicFunctions, {
    Update-ModuleManifest -Path $manifestPath `
        -FunctionsToExport $script:PublicFunctions `
        -CmdletsToExport @() `
        -AliasesToExport @()
    Invoke-Build ValidateManifest
}

task ValidateManifest {
    Test-ModuleManifest -Path $manifestPath | Out-Null
}

#
# Functions
#

function Get-RelativePathForBuild {
    param(
        [Parameter(Mandatory)]
        [string] $BasePath,

        [Parameter(Mandatory)]
        [string] $Path
    )

    $base = (Resolve-Path -LiteralPath $BasePath).ProviderPath.TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
    $resolved = (Resolve-Path -LiteralPath $Path).ProviderPath

    if ($resolved.StartsWith($base, [System.StringComparison]::OrdinalIgnoreCase)) {
        return $resolved.Substring($base.Length).Replace('\', '/')
    }

    return $resolved.Replace('\', '/')
}

function Set-DistributionRootModuleExports {
    param(
        [Parameter(Mandatory)]
        [string] $Path,

        [Parameter(Mandatory)]
        [string[]] $FunctionsToExport
    )

    $content = Get-Content -LiteralPath $Path -Raw

    $beginMarker = '# <ShowTreeDistributionExportBlock>'
    $endMarker = '# </ShowTreeDistributionExportBlock>'

    $beginCount = [regex]::Matches($content, [regex]::Escape($beginMarker)).Count
    $endCount = [regex]::Matches($content, [regex]::Escape($endMarker)).Count

    if ($beginCount -ne 1 -or $endCount -ne 1) {
        throw "Expected exactly one distribution export block in '$Path', but found $beginCount begin marker(s) and $endCount end marker(s)."
    }

    $explicitFunctionList = ($FunctionsToExport | Sort-Object | ForEach-Object {
        "    '$($_)'"
    }) -join ",`r`n"

    $replacement = @"
$beginMarker
# This block was generated by build/tasks.build.ps1.
# Do not edit this block directly in published distribution files.
# Edit src/Public/*.ps1 and rebuild the distribution instead.
Export-ModuleMember -Function @(
$explicitFunctionList
)
$endMarker
"@

    $pattern = "(?s)$([regex]::Escape($beginMarker)).*?$([regex]::Escape($endMarker))"

    $content = [regex]::Replace($content, $pattern, [System.Text.RegularExpressions.MatchEvaluator]{
        param($match)
        $replacement
    })

    $content | Set-Content -LiteralPath $Path -Encoding UTF8
}

function Get-DistInputFingerprint {
    $excludedSourceDirectories = @(
        'Tests'
    )

    $sourceFiles = Get-ChildItem -Path $moduleSrcRoot -Recurse -File |
            Where-Object {
                $relativePath = $_.FullName.Substring($moduleSrcRoot.Length + 1)

                foreach ($excludedDirectory in $excludedSourceDirectories) {
                    if ($relativePath -eq $excludedDirectory -or
                            $relativePath.StartsWith("$excludedDirectory\", [System.StringComparison]::OrdinalIgnoreCase) -or
                            $relativePath.StartsWith("$excludedDirectory/", [System.StringComparison]::OrdinalIgnoreCase)) {
                        return $false
                    }
                }

                return $true
            }

    $buildInputFiles = @(
        $manifestPath
        $rootModulePath
        (Join-Path $PSScriptRoot 'tasks.build.ps1')
        (Join-Path $PSScriptRoot 'Test-WindowsPowerShellDist.ps1')
        (Join-Path $PSScriptRoot 'Transpile-Source.ps1')
    )

    $allFiles = @($sourceFiles.FullName) + $buildInputFiles

    $entries = foreach ($path in $allFiles | Sort-Object -Unique) {
        if (-not (Test-Path -LiteralPath $path)) {
            continue
        }

        $relativePath = Get-RelativePathForBuild -BasePath $moduleRoot -Path $path
        $hash = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash

        '{0}|{1}' -f $relativePath, $hash
    }

    $combinedText = [string]::Join("`n", $entries)
    $bytes = [Text.Encoding]::UTF8.GetBytes($combinedText)
    $stream = [IO.MemoryStream]::new($bytes)

    try {
        (Get-FileHash -InputStream $stream -Algorithm SHA256).Hash
    }
    finally {
        $stream.Dispose()
    }
}

function Test-DistIsCurrent {
    if (-not (Test-Path -LiteralPath $distPath)) {
        return $false
    }

    if (-not (Test-Path -LiteralPath $fingerprintPath)) {
        return $false
    }

    $currentFingerprint = Get-DistInputFingerprint
    $previousFingerprint = Get-Content -LiteralPath $fingerprintPath -Raw

    return $currentFingerprint -eq $previousFingerprint.Trim()
}

function Save-DistFingerprint {
    if (-not (Test-Path -LiteralPath $buildCachePath)) {
        New-Item -Path $buildCachePath -ItemType Directory -Force | Out-Null
    }

    Get-DistInputFingerprint | Set-Content -LiteralPath $fingerprintPath -Encoding UTF8
}
