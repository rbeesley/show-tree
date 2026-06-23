# src\Tests\Unit\Rendering\TreeMode.Tests.ps1

BeforeAll {
    $script:TestRoot = Resolve-Path "$PSScriptRoot\..\.."
    $script:ModuleUnderTest = . "$script:TestRoot\Helpers\Import-ModuleUnderTest.ps1" `
        -StartPath $PSScriptRoot `
        -ModuleName 'ShowTree' `
        -SourceRootName 'src' `
        -Exclude 'src/Tests/*' `
        -PassThru
    $script:FixtureScripts  = @(
        "$script:TestRoot\Fixtures\TreeItemFixtures.ps1"
    )

    InModuleScope ShowTree {
        $script:testStyleProfile = Get-ShowTreeStyleProfile
        
        function script:Find-FixtureNodeByPath
        {
            param(
                [Parameter(Mandatory)]
                $Root,

                [Parameter(Mandatory)]
                [string]$Path
            )

            if ($Root.FullPath -eq $Path)
            {
                return $Root
            }

            foreach ($child in $Root.Children)
            {
                if ($child.FullPath -eq $Path)
                {
                    return $child
                }

                if ($child.IsContainer)
                {
                    $found = Find-FixtureNodeByPath -Root $child -Path $Path
                    if ($found)
                    {
                        return $found
                    }
                }
            }

            return $null
        }
    }
}

Describe "Tree mode formatting" -Skip:(-not $IsWindows) {
    It "Formats a simple TreeItem graph using Tree.com-compatible directory and file layout" {
        InModuleScope ShowTree -Parameters @{ FixtureScripts = $script:FixtureScripts } {
            param( [string[]] $FixtureScripts ); foreach ($script in $FixtureScripts) { . $script }

            $structure = [ordered]@{
                a = [ordered]@{
                    a1 = $null
                    a2 = $null
                }
                '<gap-3>' = $null
                b = [ordered]@{
                    b1 = $null
                }
            }

            $records = New-FixtureTreeRecordStream -Structure $structure
            $output = @($records | Format-Tree -Mode Tree)

            $output | Should -Be @(
                "├───a"
                "│       a1"
                "│       a2"
                "│"
                "└───b"
                "        b1"
            )
        }
    }

    It "Keeps continuation bars for later root-level siblings while rendering nested files without file connectors" {
        InModuleScope ShowTree -Parameters @{ FixtureScripts = $script:FixtureScripts } {
            param( [string[]] $FixtureScripts ); foreach ($script in $FixtureScripts) { . $script }

            $structure = [ordered]@{
                a = [ordered]@{
                    aa = $null
                    '<gap-2>' = $null
                    ab = [ordered]@{
                        ab1 = $null
                    }
                }
                '<gap-5>' = $null
                b = [ordered]@{
                    b1 = $null
                }
            }

            $records = New-FixtureTreeRecordStream -Structure $structure
            $output = @($records | Format-Tree -Mode Tree)

            $output | Should -Be @(
                "├───a"
                "│   │   aa"
                "│   │"
                "│   └───ab"
                "│           ab1"
                "│"
                "└───b"
                "        b1"
            )
        }
    }

    It "Renders gap lines in Tree mode" {
        InModuleScope ShowTree -Parameters @{ FixtureScripts = $script:FixtureScripts } {
            param( [string[]] $FixtureScripts ); foreach ($script in $FixtureScripts) { . $script }

            $structure = [ordered]@{
                a = [ordered]@{
                    a1 = $null
                }
                '<gap-2>' = $null
                b = [ordered]@{
                    b1 = $null
                }
            }

            $records = New-FixtureTreeRecordStream -Structure $structure
            $output = @($records | Format-Tree -Mode Tree)

            $output | Should -Be @(
                "├───a"
                "│       a1"
                "│"
                "└───b"
                "        b1"
            )
        }
    }

    It "Supports ASCII Tree mode connectors" {
        InModuleScope ShowTree -Parameters @{ FixtureScripts = $script:FixtureScripts } {
            param( [string[]] $FixtureScripts ); foreach ($script in $FixtureScripts) { . $script }

            $structure = [ordered]@{
                a = [ordered]@{
                    a1 = $null
                }
                '<gap-2>' = $null
                b = [ordered]@{
                    b1 = $null
                }
            }

            $records = New-FixtureTreeRecordStream -Structure $structure
            $output = @($records | Format-Tree -Mode Tree -Ascii)

            $output | Should -Be @(
                "+---a"
                "|       a1"
                "|"
                "\---b"
                "        b1"
            )
        }
    }

    It "Formats a file-only root-level listing like Tree.com when there are no later root directories" {
        InModuleScope ShowTree -Parameters @{ FixtureScripts = $script:FixtureScripts } {
            param( [string[]] $FixtureScripts ); foreach ($script in $FixtureScripts) { . $script }

            $structure = [ordered]@{
                file1 = $null
                file2 = $null
            }

            $records = New-FixtureTreeRecordStream -Structure $structure
            $output = @($records | Format-Tree -Mode Tree)

            $output | Should -Be @(
                "    file1"
                "    file2"
            )
        }
    }

    It "renders root files with Tree.com file connector spans when later root directories exist" {
        InModuleScope ShowTree -Parameters @{ FixtureScripts = $script:FixtureScripts } {
            param( [string[]] $FixtureScripts ); foreach ($script in $FixtureScripts) { . $script }

            $structure = [ordered]@{
                "root-file-1.txt" = $null
                "root-file-2.txt" = $null
                "<gap-2>" = $null
                "dir" = [ordered]@{
                    "child-file.txt" = $null
                }
            }

            $records = New-FixtureTreeRecordStream -Structure $structure
            $output = @($records | Format-Tree -Mode Tree)

            $output | Should -Be @(
                "│   root-file-1.txt"
                "│   root-file-2.txt"
                "│"
                "└───dir"
                "        child-file.txt"
            )
        }
    }

    It "Renders Tree.com file connector spans only when a later sibling directory exists" {
        InModuleScope ShowTree -Parameters @{ FixtureScripts = $script:FixtureScripts } {
            param( [string[]] $FixtureScripts ); foreach ($script in $FixtureScripts) { . $script }

            $structure = [ordered]@{
                a = [ordered]@{
                    "a-file-1.txt" = $null
                    "a-file-2.txt" = $null
                    "<gap-2>" = $null
                    aa = [ordered]@{
                        "aa-file.txt" = $null
                    }
                }
                "<gap-5>" = $null
                b = [ordered]@{
                    "b-file.txt" = $null
                }
            }

            $records = New-FixtureTreeRecordStream -Structure $structure
            $output = @($records | Format-Tree -Mode Tree)

            $output | Should -Be @(
                "├───a"
                "│   │   a-file-1.txt"
                "│   │   a-file-2.txt"
                "│   │"
                "│   └───aa"
                "│           aa-file.txt"
                "│"
                "└───b"
                "        b-file.txt"
            )
        }
    }
}

Describe "Show-Tree Tree mode gap policy" -Skip:(-not $IsWindows) {
    It "does not show gap lines in directory-only Tree mode by default" {
        InModuleScope ShowTree -Parameters @{ FixtureScripts = $script:FixtureScripts } {
            param( [string[]] $FixtureScripts ); foreach ($script in $FixtureScripts) { . $script }

            $rootPath = 'C:\Test'

            Mock Get-TreeModeHeader {
                @(
                    'Folder PATH listing for volume Test'
                    'Volume serial number is 0000-0000'
                    $Path
                )
            }

            Mock Get-RawDirectoryEntries {
                param(
                    [string]$Path,
                    [int]$Depth
                )

                if ($Path -eq $rootPath) {
                    return [pscustomobject]@{
                        Files = @()
                        Directories = @(
                            New-TreeItem -FullPath (Join-Path $Path 'a') -Name 'a' -Kind Directory -IsContainer $true -Depth $Depth -ParentPath $Path
                            New-TreeItem -FullPath (Join-Path $Path 'b') -Name 'b' -Kind Directory -IsContainer $true -Depth $Depth -ParentPath $Path
                        )
                    }
                }

                if ($Path -eq (Join-Path $rootPath 'a')) {
                    return [pscustomobject]@{
                        Files = @()
                        Directories = @(
                            New-TreeItem -FullPath (Join-Path $Path 'aa') -Name 'aa' -Kind Directory -IsContainer $true -Depth $Depth -ParentPath $Path
                        )
                    }
                }

                return [pscustomobject]@{
                    Files       = @()
                    Directories = @()
                }
            }

            $output = @(Show-Tree $rootPath -Mode Tree)

            $output | Should -Be @(
                'Folder PATH listing for volume Test'
                'Volume serial number is 0000-0000'
                'C:\Test'
                '├───a'
                '│   └───aa'
                '└───b'
                ''
            )
        }
    }

    It "shows gap lines in Tree mode when -Gap is explicitly requested" {
        InModuleScope ShowTree -Parameters @{ FixtureScripts = $script:FixtureScripts } {
            param( [string[]] $FixtureScripts ); foreach ($script in $FixtureScripts) { . $script }

            $rootPath = 'C:\Test'

            Mock Get-TreeModeHeader {
                @(
                    'Folder PATH listing for volume Test'
                    'Volume serial number is 0000-0000'
                    $Path
                )
            }

            Mock Get-RawDirectoryEntries {
                param(
                    [string]$Path,
                    [int]$Depth
                )

                if ($Path -eq $rootPath) {
                    return [pscustomobject]@{
                        Files = @()
                        Directories = @(
                            New-TreeItem -FullPath (Join-Path $Path 'a') -Name 'a' -Kind Directory -IsContainer $true -Depth $Depth -ParentPath $Path
                            New-TreeItem -FullPath (Join-Path $Path 'b') -Name 'b' -Kind Directory -IsContainer $true -Depth $Depth -ParentPath $Path
                        )
                    }
                }

                if ($Path -eq (Join-Path $rootPath 'a')) {
                    return [pscustomobject]@{
                        Files = @()
                        Directories = @(
                            New-TreeItem -FullPath (Join-Path $Path 'aa') -Name 'aa' -Kind Directory -IsContainer $true -Depth $Depth -ParentPath $Path
                        )
                    }
                }

                return [pscustomobject]@{
                    Files       = @()
                    Directories = @()
                }
            }

            $output = @(Show-Tree $rootPath -Mode Tree -Gap)

            $output | Should -Be @(
                'Folder PATH listing for volume Test'
                'Volume serial number is 0000-0000'
                'C:\Test'
                '├───a'
                '│   └───aa'
                '│'
                '└───b'
                ''
            )
        }
    }

    It "shows gap lines in Tree mode when -Files is specified" {
        InModuleScope ShowTree -Parameters @{ FixtureScripts = $script:FixtureScripts } {
            param( [string[]] $FixtureScripts ); foreach ($script in $FixtureScripts) { . $script }

            $rootPath = 'C:\Test'

            Mock Get-TreeModeHeader {
                @(
                    'Folder PATH listing for volume Test'
                    'Volume serial number is 0000-0000'
                    $Path
                )
            }

            Mock Get-RawDirectoryEntries {
                param(
                    [string]$Path,
                    [int]$Depth
                )

                if ($Path -eq $rootPath) {
                    return [pscustomobject]@{
                        Files = @()
                        Directories = @(
                            New-TreeItem -FullPath (Join-Path $Path 'a') -Name 'a' -Kind Directory -IsContainer $true -Depth $Depth -ParentPath $Path
                            New-TreeItem -FullPath (Join-Path $Path 'b') -Name 'b' -Kind Directory -IsContainer $true -Depth $Depth -ParentPath $Path
                        )
                    }
                }

                if ($Path -eq (Join-Path $rootPath 'a')) {
                    return [pscustomobject]@{
                        Files = @(
                            New-TreeItem -FullPath (Join-Path $Path 'file.txt') -Name 'file.txt' -Kind File -IsContainer $false -Depth $Depth -ParentPath $Path
                        )
                        Directories = @()
                    }
                }

                return [pscustomobject]@{
                    Files       = @()
                    Directories = @()
                }
            }

            $output = @(Show-Tree $rootPath -Mode Tree -Files)

            $output | Should -Be @(
                'Folder PATH listing for volume Test'
                'Volume serial number is 0000-0000'
                'C:\Test'
                '├───a'
                '│       file.txt'
                '│'
                '└───b'
                ''
            )
        }
    }
}

Describe "Tree mode Win32 provider mapping" -Skip:(-not $IsWindows) {
    It "Maps mocked Win32 provider output to a flattened TreeItem graph with correct depth and parent paths" {
        InModuleScope ShowTree -Parameters @{ FixtureScripts = $script:FixtureScripts } {
            param( [string[]] $FixtureScripts ); foreach ($script in $FixtureScripts) { . $script }

            # 1. Define the structure (Source of Truth)
            $structure = [ordered]@{
                a = [ordered]@{
                    a1 = $null
                    a2 = $null
                }
                b = [ordered]@{
                    b1 = $null
                }
            }

            # 2. Build the Fixture Tree and Provider
            # New-FixtureTree automatically handles FullPath/IsContainer/etc.
            $tree = New-FixtureTree -Structure $structure
            $provider = New-FixtureTreeChildProvider -Root $tree
            $rootPath = $provider.RootPath

            # 3. Mock the resolution and provider factory
            Mock Resolve-Path { 
                [pscustomobject]@{ ProviderPath = $rootPath; Path = $rootPath } 
            }
            Mock New-TreeChildProvider { $provider }

            # 4. Execute the command under test
            # Use Depth 2 to get children and grandchildren
            $records = @(Get-TreeItem -Path $rootPath -ProviderMode Win32 -Depth 2)

            # 5. Assertions
            $items = $records.TreeItem
            $items.Name | Should -Be @('a', 'a1', 'a2', 'b', 'b1')

            # Verify Depth and ParentPath calculations performed by Get-TreeItem/Traversal
            $a = $items | Where-Object Name -eq 'a'
            $a.Depth      | Should -Be 0
            $a.ParentPath | Should -Be $rootPath

            $a1 = $items | Where-Object Name -eq 'a1'
            $a1.Depth      | Should -Be 1
            $a1.ParentPath | Should -Be (Join-Path $rootPath 'a')

            $b = $items | Where-Object Name -eq 'b'
            $b.Depth      | Should -Be 0
            $b.ParentPath | Should -Be $rootPath

            $b1 = $items | Where-Object Name -eq 'b1'
            $b1.Depth      | Should -Be 1
            $b1.ParentPath | Should -Be (Join-Path $rootPath 'b')
        }
    }

    It "Produces Tree.com-compatible rendering from mocked Win32 provider output" {
        InModuleScope ShowTree -Parameters @{ FixtureScripts = $script:FixtureScripts } {
            param( [string[]] $FixtureScripts ); foreach ($script in $FixtureScripts) { . $script }

            # 1. Define the structure (Source of Truth)
            $structure = [ordered]@{
                a = [ordered]@{
                    a1 = $null
                    a2 = $null
                }
                b = [ordered]@{
                    b1 = $null
                }
            }

            # 2. Build the Fixture Tree and Provider
            # New-FixtureTree automatically handles FullPath/IsContainer/etc.
            $tree = New-FixtureTree -Structure $structure
            $provider = New-FixtureTreeChildProvider -Root $tree
            $rootPath = $provider.RootPath

            # 3. Mock the resolution and provider factory
            Mock Resolve-Path { 
                [pscustomobject]@{ ProviderPath = $rootPath; Path = $rootPath } 
            }
            Mock New-TreeChildProvider { $provider }

            # 4. Execute the command under test
            # Use Depth 2 to get children and grandchildren
            $records = @(Get-TreeItem -Path $rootPath -ProviderMode Win32 -Depth 2)
            $output = @($records | Format-Tree -Mode Tree)

            $output | Should -Be @(
                '├───a'
                '│       a1'
                '│       a2'
                '│'
                '└───b'
                '        b1'
            )
        }
    }
}

Describe "Tree mode Win32 provider ordering" -Skip:(-not $IsWindows) {
    It "preserves tree.com-compatible Win32 ordering without applying deterministic sorting" {
        InModuleScope ShowTree -Parameters @{ FixtureScripts = $script:FixtureScripts } {
            param( [string[]] $FixtureScripts ); foreach ($script in $FixtureScripts) { . $script }

            $rootPath = 'C:\Test'

            Mock Get-RawDirectoryEntries {
                param(
                    [string]$Path,
                    [int]$Depth
                )

                if ($Path -eq $rootPath) {
                    return [pscustomobject]@{
                        Files = @(
                            New-TreeItem -FullPath (Join-Path $Path 'z-file.txt') -Name 'z-file.txt' -Kind File -IsContainer $false -Depth $Depth -ParentPath $Path
                            New-TreeItem -FullPath (Join-Path $Path 'a-file.txt') -Name 'a-file.txt' -Kind File -IsContainer $false -Depth $Depth -ParentPath $Path
                        )
                        Directories = @(
                            New-TreeItem -FullPath (Join-Path $Path 'z-dir') -Name 'z-dir' -Kind Directory -IsContainer $true -Depth $Depth -ParentPath $Path
                            New-TreeItem -FullPath (Join-Path $Path 'a-dir') -Name 'a-dir' -Kind Directory -IsContainer $true -Depth $Depth -ParentPath $Path
                        )
                    }
                }

                return [pscustomobject]@{
                    Files       = @()
                    Directories = @()
                }
            }

            $items = @(Get-TreeItem -Path $rootPath -ProviderMode Win32 -Depth 0)

            $items.TreeItem.Name | Should -Be @(
                'z-file.txt'
                'a-file.txt'
                'z-dir'
                'a-dir'
            )
        }
    }
}