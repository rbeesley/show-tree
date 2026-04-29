# ShowTree\Tests\Private\Show-TreeInternal.Tests.ps1

InModuleScope ShowTree {

    BeforeAll {
        . "$PSScriptRoot/PrivateHelpers.ps1"

        $fixture = New-TestTree ([ordered]@{
            root = [ordered]@{
                'zeta.txt' = $null

                deep = [ordered]@{
                    a = [ordered]@{
                        b = [ordered]@{
                            c = [ordered]@{
                                d = [ordered]@{
                                    'file.txt' = $null
                                }
                            }
                        }
                    }
                }

                emptyDir = [ordered]@{}  # directory with no children

                hiddenDir = [ordered]@{
                    # Attributes = 'Hidden'
                    # Children   = [ordered]@{
                    #     'hd1.txt' = $null
                    # }
                    'hd1.txt' = $null
                }

                mixed = [ordered]@{
                    'mf1.txt' = $null
                    'mf2.txt' = $null
                    subMixed = [ordered]@{
                        'sm1.txt' = $null
                        'sm2.txt' = $null
                    }
                }

                onlyDirs = [ordered]@{
                    d1 = [ordered]@{}
                    d2 = [ordered]@{}
                }

                onlyFiles = [ordered]@{
                    'f1.txt' = $null
                    'f2.txt' = $null
                }

                systemDir = [ordered]@{
                    # Attributes = 'System'
                    # Children   = [ordered]@{
                    #     'sd1.txt' = $null
                    # }
                    'sd1.txt' = $null
                }
            }
        })

        $script:GapState = [pscustomobject]@{
            LastGapMode = [GapMode]::None
        }
    }

    # FIXME : Convert-TestTreeToRaw doesn't yet support a way to set attributes on files and directories
    Describe "Tree.com compatibility" -Skip {

        It "Matches Tree.com output for a simple tree" {

            Mock Get-RawDirectoryEntries {
                param($Path)
                Convert-TestTreeToRaw -Root $fixture -Path $Path
            }

            $result = Show-TreeInternal `
                -Path $fixture.FullName `
                -Tree `
                -Gap:$true `
                -IncludeFiles:$true `
                -HideHidden:$false `
                -HideSystem:$false
                | Out-String

            $expected = @"
│   zeta.txt
│
├───deep
│   └───a
│       └───b
│           └───c
│               └───d
│                       file.txt
│                   
├───emptyDir
├───hiddenDir
│       hd1.txt
│   
├───mixed
│   │   mf1.txt
│   │   mf2.txt
│   │
│   └───subMixed
│           sm1.txt
│           sm2.txt
│       
├───onlyDirs
│   ├───d1
│   └───d2
├───onlyFiles
│       f1.txt
│       f2.txt
│   
└───systemDir
        sd1.txt
"@.Trim()

            $result.Trim() | Should -Be $expected
        }
    }
}
