# build/Transpile-Source.ps1
param(
    [Parameter(Mandatory)]
    [string]$SourcePath,
    [Parameter(Mandatory)]
    [string]$DestinationPath
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path $SourcePath)) {
    throw "Source path not found: $SourcePath"
}

# Ensure destination directory exists
$destDir = Split-Path $DestinationPath -Parent
if (-not (Test-Path $destDir)) {
    New-Item -Path $destDir -ItemType Directory -Force | Out-Null
}

$content = Get-Content $SourcePath -Raw
$ast = [System.Management.Automation.Language.Parser]::ParseInput($content, [ref]$null, [ref]$null)

# Find all ternary expressions
$ternaries = $ast.FindAll({ $args[0] -is [System.Management.Automation.Language.TernaryExpressionAst] }, $true)

if ($ternaries.Count -gt 0) {
    Write-Host "Transpiling $($ternaries.Count) ternary operator(s) in $SourcePath"
    
    while ($true) {
        $ast = [System.Management.Automation.Language.Parser]::ParseInput($content, [ref]$null, [ref]$null)
        $t = $ast.FindAll({ $args[0] -is [System.Management.Automation.Language.TernaryExpressionAst] }, $true) | 
             Sort-Object { $_.Extent.StartOffset } -Descending | 
             Select-Object -First 1
        
        if (-not $t) { break }

        $condition = $content.Substring($t.Condition.Extent.StartOffset, $t.Condition.Extent.EndOffset - $t.Condition.Extent.StartOffset)
        $ifTrue = $content.Substring($t.IfTrue.Extent.StartOffset, $t.IfTrue.Extent.EndOffset - $t.IfTrue.Extent.StartOffset)
        $ifFalse = $content.Substring($t.IfFalse.Extent.StartOffset, $t.IfFalse.Extent.EndOffset - $t.IfFalse.Extent.StartOffset)
        
        $newText = "(&{if($condition){$ifTrue}else{$ifFalse}})"
        
        $start = $t.Extent.StartOffset
        $end = $t.Extent.EndOffset
        
        $content = $content.Substring(0, $start) + $newText + $content.Substring($end)
    }
}

# Write the transpiled output with a UTF-8 BOM
$utf8Bom = New-Object System.Text.UTF8Encoding($true)
[System.IO.File]::WriteAllText($DestinationPath, $content, $utf8Bom)
