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

# ---------------------------------------------------------------------------
# AST Transformation Engine
# ---------------------------------------------------------------------------

function Transpile-Ast {
    param(
        [string]$Source,
        [scriptblock]$MatchCondition,
        [scriptblock]$ReplacementGenerator
    )

    $currentSource = $Source
    while ($true) {
        $tokens = $null
        $errors = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseInput($currentSource, [ref]$tokens, [ref]$errors)
        
        $matches = $ast.FindAll($MatchCondition, $true) | Sort-Object { $_.Extent.StartOffset } -Descending
        
        if (-not $matches) { break }

        # Replace the last one first to preserve offsets for earlier ones (if we were doing it in one pass)
        # But we loop and re-parse to be absolutely safe with nested expressions.
        $node = $matches[0]
        
        $newText = & $ReplacementGenerator $node $currentSource
        
        if ($null -eq $newText) { break }

        $start = $node.Extent.StartOffset
        $end = $node.Extent.EndOffset
        $currentSource = $currentSource.Substring(0, $start) + $newText + $currentSource.Substring($end)
    }
    return $currentSource
}

# 1. Ternary Expressions: $a ? $b : $c -> (&{if($a){$b}else{$c}})
$content = Transpile-Ast -Source $content `
    -MatchCondition { $args[0] -is [System.Management.Automation.Language.TernaryExpressionAst] } `
    -ReplacementGenerator {
        param($node, $src)
        $cond = $src.Substring($node.Condition.Extent.StartOffset, $node.Condition.Extent.EndOffset - $node.Condition.Extent.StartOffset)
        $ifT  = $src.Substring($node.IfTrue.Extent.StartOffset, $node.IfTrue.Extent.EndOffset - $node.IfTrue.Extent.StartOffset)
        $ifF  = $src.Substring($node.IfFalse.Extent.StartOffset, $node.IfFalse.Extent.EndOffset - $node.IfFalse.Extent.StartOffset)
        return "(&{if($cond){$ifT}else{$ifF}})"
    }

# 2. Static New: [Type]::new(...) -> (New-Object -TypeName Type -ArgumentList ...)
$content = Transpile-Ast -Source $content `
    -MatchCondition {
        $node = $args[0]
        $node -is [System.Management.Automation.Language.InvokeMemberExpressionAst] -and 
        $node.Member -is [System.Management.Automation.Language.StringConstantExpressionAst] -and
        $node.Member.Value -eq 'new' -and
        $node.Static
    } `
    -ReplacementGenerator {
        param($node, $src)
        $type = $node.Expression.Extent.Text
        $argsText = if ($node.Arguments) {
            $src.Substring($node.Arguments[0].Extent.StartOffset, $node.Extent.EndOffset - 1 - $node.Arguments[0].Extent.StartOffset)
        } else { "" }

        $newText = "New-Object -TypeName $type"
        if ($argsText) { $newText += " -ArgumentList $argsText" }
        return "($newText)"
    }

# ---------------------------------------------------------------------------
# Brittle Regex Cleanups (Legacy support for things hard to do in AST or not yet moved)
# ---------------------------------------------------------------------------

# Rule 3: Ensure $results = @() becomes a List if we use .Add later
$content = [regex]::Replace($content, '(?m)^\s*(\$(?:results|children|childPool|roots))\s*=\s*@\(\)', '$1 = New-Object System.Collections.Generic.List[object]')

# Fix List[object]::new() that might have been missed
$content = [regex]::Replace($content, '\[System\.Collections\.Generic\.List\[object\]\]::new\(\)', '(New-Object System.Collections.Generic.List[object])')

# Use GetType().IsArray check for count to be robust in PS5.1
$content = [regex]::Replace($content, '(?<!@\()\$roots\.Count', '(&{ if($null -ne $roots -and $roots.GetType().IsArray){ $roots.Length } else { $roots.Count } })')

# Rule 6: Fix Resolve-Path -ErrorAction SilentlyContinue pattern
$resolvePathPattern = '(?s)\$resolvedPath\s*=\s*Resolve-Path\s*\$Path\s*-ErrorAction\s*SilentlyContinue\s*if\s*\(-not\s*\$resolvedPath\)\s*\{\s*\$resolvedPath\s*=\s*\$Path\s*\}\s*else\s*\{\s*\$resolvedPath\s*=\s*\$resolvedPath\.Path\s*\}'
if ($content -match $resolvePathPattern) {
    $newResolve = '$resolvedPath = $null; $errPref = $ErrorActionPreference; $ErrorActionPreference = "SilentlyContinue"; try { $res = Resolve-Path $Path; if($null -ne $res){ $resolvedPath = $res.Path } } catch {}; $ErrorActionPreference = $errPref; if($null -eq $resolvedPath){ $resolvedPath = $Path }'
    $content = [regex]::Replace($content, $resolvePathPattern, $newResolve)
}

# Fix types in New-Object -TypeName [Type] to just Type
$content = $content -replace 'New-Object -TypeName \[([^\]]+)\]', 'New-Object -TypeName $1'

# Write the transpiled output with a UTF-8 BOM
$utf8Bom = New-Object System.Text.UTF8Encoding($true)
[System.IO.File]::WriteAllText($DestinationPath, $content, $utf8Bom)
