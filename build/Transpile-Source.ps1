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
        [string]$Label = "Transforming",
        [scriptblock]$MatchCondition,
        [scriptblock]$ReplacementGenerator
    )

    $currentSource = $Source
    $iteration = 0
    while ($true) {
        $tokens = $null
        $errors = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseInput($currentSource, [ref]$tokens, [ref]$errors)
        
        $matches = $ast.FindAll($MatchCondition, $true) | Sort-Object { $_.Extent.StartOffset } -Descending
        
        if (-not $matches) { break }

        $iteration++
        Write-Progress -Activity "Transpiling AST" -Status "$Label (Match $iteration)"

        # Replace the last one first to preserve offsets for earlier ones (if we were doing it in one pass)
        # But we loop and re-parse to be absolutely safe with nested expressions.
        $node = $matches[0]
        
        $newText = & $ReplacementGenerator $node $currentSource
        
        if ($null -eq $newText) { break }

        $start = $node.Extent.StartOffset
        $end = $node.Extent.EndOffset
        $currentSource = $currentSource.Substring(0, $start) + $newText + $currentSource.Substring($end)
    }
    Write-Progress -Activity "Transpiling AST" -Status "$Label - Completed" -Completed
    return $currentSource
}

# Ternary Expressions: $a ? $b : $c -> (&{if($a){$b}else{$c}})
$content = Transpile-Ast -Source $content -Label "Ternary" `
    -MatchCondition { $args[0] -is [System.Management.Automation.Language.TernaryExpressionAst] } `
    -ReplacementGenerator {
    param($node, $src)
    $cond = $src.Substring($node.Condition.Extent.StartOffset, $node.Condition.Extent.EndOffset - $node.Condition.Extent.StartOffset)
    $ifT  = $src.Substring($node.IfTrue.Extent.StartOffset, $node.IfTrue.Extent.EndOffset - $node.IfTrue.Extent.StartOffset)
    $ifF  = $src.Substring($node.IfFalse.Extent.StartOffset, $node.IfFalse.Extent.EndOffset - $node.IfFalse.Extent.StartOffset)
    return "(&{if($cond){$ifT}else{$ifF}})"
}

# Null-coalescing assignment: $a ??= $b -> if ($null -eq $a) { $a = $b }
$content = Transpile-Ast -Source $content -Label "Null-Coalesce" `
    -MatchCondition {
    $node = $args[0]
    $node -is [System.Management.Automation.Language.AssignmentStatementAst] -and
            $node.Extent.Text -match '\?\?='
} `
    -ReplacementGenerator {
    param($node, $src)
    $left = $src.Substring(
            $node.Left.Extent.StartOffset,
            $node.Left.Extent.EndOffset - $node.Left.Extent.StartOffset
    )
    $right = $src.Substring(
            $node.Right.Extent.StartOffset,
            $node.Right.Extent.EndOffset - $node.Right.Extent.StartOffset
    )

    return "if (`$null -eq $left) { $left = $right }"
}

# Static New: [Type]::new(...) -> (New-Object -TypeName Type -ArgumentList ...)
$content = Transpile-Ast -Source $content -Label "Static New" `
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

# Generic List AddRange: $list.AddRange($other) -> foreach($i in $other){[void]$list.Add($i)}
$content = Transpile-Ast -Source $content -Label "AddRange" `
    -MatchCondition {
    $node = $args[0]
    $node -is [System.Management.Automation.Language.InvokeMemberExpressionAst] -and
            $node.Member -is [System.Management.Automation.Language.StringConstantExpressionAst] -and
            $node.Member.Value -eq 'AddRange' -and
            -not $node.Static
} `
    -ReplacementGenerator {
    param($node, $src)
    $list = $src.Substring($node.Expression.Extent.StartOffset, $node.Expression.Extent.EndOffset - $node.Expression.Extent.StartOffset)
    $other = $src.Substring($node.Arguments[0].Extent.StartOffset, $node.Arguments[0].Extent.EndOffset - $node.Arguments[0].Extent.StartOffset)
    return "foreach(`$____item in $other){[void]$list.Add(`$____item)}"
}

# New-Object Type unwrapping: New-Object -TypeName [Type] -> New-Object -TypeName Type
$content = Transpile-Ast -Source $content -Label "New-Object Type" `
    -MatchCondition {
    $node = $args[0]
    if ($node -isnot [System.Management.Automation.Language.CommandAst] -or
        $node.GetCommandName() -ne 'New-Object') {
        return $false
    }

    # Only match if it actually contains a [Type] literal for TypeName
    $typeNameFound = $false
    foreach ($element in $node.CommandElements) {
        if ($element -is [System.Management.Automation.Language.CommandParameterAst] -and
                ($element.ParameterName -eq 'TypeName' -or $element.ParameterName -eq 'T')) {
            $typeNameFound = $true
            continue
        }
        if ($typeNameFound) {
            return ($element -is [System.Management.Automation.Language.StringConstantExpressionAst] -and
                    $element.Value -match '^\[.+\]$')
        }
    }
    return $false
} `
    -ReplacementGenerator {
    param($node, $src)
    $typeNameFound = $false
    $newElements = foreach ($element in $node.CommandElements) {
        if ($element -is [System.Management.Automation.Language.CommandParameterAst] -and
                ($element.ParameterName -eq 'TypeName' -or $element.ParameterName -eq 'T')) {
            $typeNameFound = $true
            $element.Extent.Text
            continue
        }

        if ($typeNameFound -and $element -is [System.Management.Automation.Language.StringConstantExpressionAst] -and $element.Value -match '^\[(.+)\]$') {
            $typeNameFound = $false
            $matches[1]
            continue
        }

        $typeNameFound = $false
        $element.Extent.Text
    }

    return $newElements -join ' '
}

# ---------------------------------------------------------------------------
# Write the transpiled output with a UTF-8 BOM
# ---------------------------------------------------------------------------
$utf8Bom = New-Object System.Text.UTF8Encoding($true)
[System.IO.File]::WriteAllText($DestinationPath, $content, $utf8Bom)
