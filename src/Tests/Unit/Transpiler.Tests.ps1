# src/Tests/Unit/Transpiler.Tests.ps1

Describe "Transpile-Source" {
    BeforeAll {
        $script:TranspilerPath = Resolve-Path (Join-Path $PSScriptRoot "..\..\..\build\Transpile-Source.ps1")
        
        function Invoke-Transpilation {
            param($SourceCode)
            $tempSrc = [System.IO.Path]::GetTempFileName() + ".ps1"
            $tempDest = [System.IO.Path]::GetTempFileName() + ".ps1"
            try {
                $SourceCode | Out-File $tempSrc -Encoding utf8
                & $script:TranspilerPath -SourcePath $tempSrc -DestinationPath $tempDest
                Get-Content $tempDest -Raw
            }
            finally {
                if (Test-Path $tempSrc) { Remove-Item $tempSrc }
                if (Test-Path $tempDest) { Remove-Item $tempDest }
            }
        }
    }

    It "Transpiles null-coalescing assignment" {
        $input = '$Value ??= "fallback"'
        $output = Invoke-Transpilation $input
        $output | Should -Match 'if \(\$null -eq \$Value\) \{ \$Value = "fallback" \}'
    }

    It "Transpiles complex null-coalescing assignment" {
        $input = '$Link ??= [PSCustomObject]@{ Type = "None" }'
        $output = Invoke-Transpilation $input
        $output | Should -Match 'if \(\$null -eq \$Link\) \{ \$Link = \[PSCustomObject\]@\{ Type = "None" \} \}'
    }

    It "Transpiles ternary expressions" {
        $input = '$a ? $b : $c'
        $output = Invoke-Transpilation $input
        $output | Should -Match '\(&\{if\(\$a\)\{\$b\}else\{\$c\}\}\)'
    }

    It "Transpiles static new" {
        $input = '[System.Collections.Generic.List[string]]::new()'
        $output = Invoke-Transpilation $input
        $output | Should -Match '\(New-Object -TypeName System\.Collections\.Generic\.List\[string\]\)'
    }
}
