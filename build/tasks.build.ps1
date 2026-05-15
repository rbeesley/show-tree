# build/tasks.build.ps1

param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$moduleRoot     = Split-Path $PSScriptRoot -Parent
$moduleSrcRoot  = Join-Path  $moduleRoot     'src'
$manifestPath   = Join-Path  $moduleRoot     'ShowTree.psd1'
$rootModulePath = Join-Path  $moduleRoot     'ShowTree.psm1'
$publicPath     = Join-Path  $moduleSrcRoot  'Public'
$distPath       = Join-Path  $moduleRoot     'dist'
$buildCachePath = Join-Path  $PSScriptRoot   '.cache'
$fingerprintPath = Join-Path $buildCachePath 'dist.fingerprint'

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
        (Join-Path $PSScriptRoot 'Transpile-Source.ps1')
        (Join-Path $PSScriptRoot 'tasks.build.ps1')
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

task Clean {
    if (Test-Path $distPath) {
        Remove-Item $distPath -Recurse -Force
    }
}

task BuildDist {
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

task ForceBuild Clean, UpdateManifest, BuildDist, {
    Save-DistFingerprint
}

task BuildIfNeeded UpdateManifest, {
    if (Test-DistIsCurrent) {
        Write-Host "dist is current; skipping build." -ForegroundColor DarkGray
        return
    }

    Write-Host "dist is stale; rebuilding." -ForegroundColor Cyan
    Invoke-Build Clean, BuildDist
    Save-DistFingerprint
}

task Build BuildIfNeeded, {
    if (-not (Test-DistIsCurrent)) {
        Invoke-Build ForceBuild
    }
}

task Test ValidateManifest, {
    Invoke-Pester -Path (Join-Path $moduleSrcRoot 'Tests') -Output Detailed
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

task TestAll Test, TestDist, TestDesktop, {
    # Full source tests + dist smoke tests
}

task default Test
