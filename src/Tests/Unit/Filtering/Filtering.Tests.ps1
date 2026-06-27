# src\Tests\Unit\Filtering\Filtering.Tests.ps1

BeforeAll {
    $script:TestRoot = Resolve-Path "$PSScriptRoot\..\.."
    $script:ModuleUnderTest = . "$script:TestRoot\Helpers\Import-ModuleUnderTest.ps1" `
        -StartPath $PSScriptRoot `
        -ModuleName 'ShowTree' `
        -SourceRootName 'src' `
        -Exclude 'src/Tests/*' `
        -PassThru
    $script:FixtureScripts  = @(
        "$script:TestRoot\Helpers\PrivateHelpers.ps1"
    )
}

Describe "TreeItem Visibility" {
    It "Excludes exact matches" {
        InModuleScope ShowTree -Parameters @{ FixtureScripts = $script:FixtureScripts } {
            param( [string[]] $FixtureScripts ); foreach ($script in $FixtureScripts) { . $script }

            $item = New-TestItem -Name ".git"
            $visible = Test-TreeItemVisible -Item $item -Exclude ".git"
            $visible | Should -Be $false

            $item2 = New-TestItem -Name ".github"
            $visible2 = Test-TreeItemVisible -Item $item2 -Exclude ".git"
            $visible2 | Should -Be $true
        }
    }

    It "Treats a trailing slash filter as directory-only" {
        InModuleScope ShowTree -Parameters @{ FixtureScripts = $script:FixtureScripts } {
            param( [string[]] $FixtureScripts ); foreach ($script in $FixtureScripts) { . $script }

            $rootPath = $IsWindows ? 'C:\Test' : '/tmp/test'

            $directory = New-TestItem `
                -Name "TestFixtures" `
                -ParentPath $rootPath `
                -IsDirectory:$true `
                -Attributes ([IO.FileAttributes]::Directory)

            $file = New-TestItem `
                -Name "TestFixtures" `
                -ParentPath $rootPath `
                -IsDirectory:$false

            Test-TreeItemVisible `
                -Item $directory `
                -Exclude "TestFixtures\" `
                -RootPath $rootPath |
                    Should -Be $false

            Test-TreeItemVisible `
                -Item $file `
                -Exclude "TestFixtures\" `
                -RootPath $rootPath |
                    Should -Be $true
        }
    }

    It "Matches nested relative directory filters only at the specified relative path" {
        InModuleScope ShowTree -Parameters @{ FixtureScripts = $script:FixtureScripts } {
            param( [string[]] $FixtureScripts ); foreach ($script in $FixtureScripts) { . $script }

            $rootPath = $IsWindows ? 'C:\Test' : '/tmp/test'

            $srcFixtures = New-TestItem `
                -Name "TestFixtures" `
                -ParentPath (Join-Path $rootPath 'src') `
                -IsDirectory:$true `
                -Attributes ([IO.FileAttributes]::Directory)

            $testFixtures = New-TestItem `
                -Name "TestFixtures" `
                -ParentPath (Join-Path $rootPath 'test') `
                -IsDirectory:$true `
                -Attributes ([IO.FileAttributes]::Directory)

            # In the engine, relative paths are now expected to be resolved to absolute paths or 
            # relative to the current working location.
            $excludePath = Join-Path $rootPath 'src\TestFixtures'

            Test-TreeItemVisible `
                -Item $srcFixtures `
                -Exclude $excludePath `
                -RootPath $rootPath |
                    Should -Be $false

            Test-TreeItemVisible `
                -Item $testFixtures `
                -Exclude $excludePath `
                -RootPath $rootPath |
                    Should -Be $true
        }
    }

    It "Matches nested relative directory filters with glob stars" {
        InModuleScope ShowTree -Parameters @{ FixtureScripts = $script:FixtureScripts } {
            param( [string[]] $FixtureScripts ); foreach ($script in $FixtureScripts) { . $script }

            $rootPath = $IsWindows ? 'C:\Test' : '/tmp/test'

            $srcFixtures = New-TestItem `
                -Name "TestFixtures" `
                -ParentPath (Join-Path $rootPath 'src') `
                -IsDirectory:$true `
                -Attributes ([IO.FileAttributes]::Directory)

            # Resolve the wildcard path against the mock root for the test
            $excludePath = Join-Path $rootPath '*\TestFixtures'

            Test-TreeItemVisible `
                -Item $srcFixtures `
                -Exclude $excludePath `
                -RootPath $rootPath |
                    Should -Be $false
        }
    }

    It "Still allows name-only filters to match items with that name anywhere in the tree" {
        InModuleScope ShowTree -Parameters @{ FixtureScripts = $script:FixtureScripts } {
            param( [string[]] $FixtureScripts ); foreach ($script in $FixtureScripts) { . $script }

            $rootPath = $IsWindows ? 'C:\Test' : '/tmp/test'
            $nestedParent = Join-Path $rootPath 'src'

            $nestedFixtures = New-TestItem `
                -Name "TestFixtures" `
                -ParentPath $nestedParent `
                -IsDirectory:$true `
                -Attributes ([IO.FileAttributes]::Directory)

            Test-TreeItemVisible `
                -Item $nestedFixtures `
                -Exclude "TestFixtures" `
                -RootPath $rootPath |
                    Should -Be $false
        }
    }

    It "Glob include resurrects items excluded by glob" {
        InModuleScope ShowTree -Parameters @{ FixtureScripts = $script:FixtureScripts } {
            param( [string[]] $FixtureScripts ); foreach ($script in $FixtureScripts) { . $script }

            $item = New-TestItem -Name ".github"
            $visible = Test-TreeItemVisible -Item $item -Exclude ".*" -Include ".github"
            $visible | Should -Be $true

            $item2 = New-TestItem -Name ".git"
            $visible2 = Test-TreeItemVisible -Item $item2 -Exclude ".*" -Include ".github"
            $visible2 | Should -Be $false
        }
    }

    It "Exact exclude beats glob include" {
        InModuleScope ShowTree -Parameters @{ FixtureScripts = $script:FixtureScripts } {
            param( [string[]] $FixtureScripts ); foreach ($script in $FixtureScripts) { . $script }

            $item = New-TestItem -Name ".git"
            $visible = Test-TreeItemVisible -Item $item -Exclude ".git" -Include ".git*"
            $visible | Should -Be $false

            $item2 = New-TestItem -Name ".gitignore"
            $visible2 = Test-TreeItemVisible -Item $item2 -Exclude ".git" -Include ".git*"
            $visible2 | Should -Be $true
        }
    }

    It "Include resurrects hidden items" {
        InModuleScope ShowTree -Parameters @{ FixtureScripts = $script:FixtureScripts } {
            param( [string[]] $FixtureScripts ); foreach ($script in $FixtureScripts) { . $script }

            $item = New-TestItem -Name ".config" -Attributes ([IO.FileAttributes]::Hidden)
            $visible = Test-TreeItemVisible -Item $item -HideHidden -Include ".config"
            $visible | Should -Be $true
        }
    }

    It 'Rescues a specific subdirectory and its children from an excluded parent branch' {
        InModuleScope ShowTree -Parameters @{ FixtureScripts = $script:FixtureScripts } {
            param( [string[]] $FixtureScripts ); foreach ($script in $FixtureScripts) { . $script }

            # Use absolute paths for the mock root, but test relative filter resolution
            $root = $IsWindows ? 'C:\TestFixtures' : '/tmp/TestFixtures'

            $dir1 = [PSCustomObject]@{ FullName = Join-Path $root 'Directories'; Name = 'Directories'; IsContainer = $true; FullPath = Join-Path $root 'Directories' }
            $nested = [PSCustomObject]@{ FullName = Join-Path $dir1.FullName 'nested-dir'; Name = 'nested-dir'; IsContainer = $true; FullPath = Join-Path $dir1.FullName 'nested-dir' }
            $child = [PSCustomObject]@{ FullName = Join-Path $nested.FullName 'leaf.txt'; Name = 'leaf.txt'; IsContainer = $false; FullPath = Join-Path $nested.FullName 'leaf.txt' }
            $sibling = [PSCustomObject]@{ FullName = Join-Path $dir1.FullName 'hidden-dir'; Name = 'hidden-dir'; IsContainer = $true; FullPath = Join-Path $dir1.FullName 'hidden-dir' }

            $exclude = @('.\Directories\')
            $include = @('.\Directories\nested-dir\')
            $traversalRoot = $root

            # 1. 'Directories' should be visible as structural ancestor
            Test-TreeItemVisible -Item $dir1 -Include $include -Exclude $exclude -RootPath $traversalRoot | Should -Be $true
            Test-TreeItemRecurse -Item $dir1 -Include $include -Exclude $exclude -RootPath $traversalRoot | Should -Be $true

            # 2. 'nested-dir' should be visible as a direct match
            Test-TreeItemVisible -Item $nested -Include $include -Exclude $exclude -RootPath $traversalRoot | Should -Be $true
            Test-TreeItemRecurse -Item $nested -Include $include -Exclude $exclude -RootPath $traversalRoot | Should -Be $true

            # 3. 'leaf.txt' should be visible as a descendant of inclusion
            Test-TreeItemVisible -Item $child -Include $include -Exclude $exclude -RootPath $traversalRoot | Should -Be $true

                # 4. 'hidden-dir' (sibling) should be hidden because it matches the excluded branch and is not an ancestor/descendant
                Test-TreeItemVisible -Item $sibling -Include $include -Exclude $exclude -RootPath $traversalRoot | Should -Be $false
        }
    }

    It 'Rescues a branch when a descendant matches a name-only inclusion but the branch is excluded by path' {
        InModuleScope ShowTree -Parameters @{ FixtureScripts = $script:FixtureScripts } {
            param( [string[]] $FixtureScripts ); foreach ($script in $FixtureScripts) { . $script }

            $root = $IsWindows ? 'C:\Test' : '/tmp/test'
            $dirPath = Join-Path $root 'Directories'
            
            # Construct hierarchy
            $nested = New-TestItem -Name 'nested-dir' -ParentPath $dirPath -IsDirectory:$true
            $dir = New-TestItem -Name 'Directories' -ParentPath $root -IsDirectory:$true -Children @($nested)

            # Simulate the resolution that happens in Get-TreeItem:
            # 1. The original name inclusion
            # 2. The candidate absolute path discovered during preprocessing
            $include = @('nested-dir\', $nested.FullPath)
            $exclude = @([System.IO.Path]::GetFullPath((Join-Path $root 'Directories')))

            # 'Directories' should be visible as an ancestor to 'nested-dir'
            Test-TreeItemVisible -Item $dir -Include $include -Exclude $exclude -RootPath $root | Should -Be $true
            
            # 'nested-dir' should be visible as a direct match
            Test-TreeItemVisible -Item $nested -Include $include -Exclude $exclude -RootPath $root | Should -Be $true
        }
    }

    It "Excludes a subdirectory using a relative path filter" {
        InModuleScope ShowTree -Parameters @{ FixtureScripts = $script:FixtureScripts } {
            param( [string[]] $FixtureScripts ); foreach ($script in $FixtureScripts) { . $script }

            $rootPath = $IsWindows ? 'C:\Test' : '/tmp/test'
            $dirPath = Join-Path $rootPath 'Directories'

            $item = New-TestItem `
                -Name "Directories" `
                -ParentPath $rootPath `
                -IsDirectory:$true `
                -Attributes ([IO.FileAttributes]::Directory)

            $child = New-TestItem `
                -Name "child" `
                -ParentPath $dirPath `
                -IsDirectory:$false

            # Resolve the relative path to absolute as Show-Tree would do
            $exclude = Join-Path $rootPath 'Directories'

            # Direct match exclusion
            Test-TreeItemVisible -Item $item -Exclude $exclude -RootPath $rootPath | Should -Be $false

            # Descendant exclusion
            Test-TreeItemVisible -Item $child -Exclude $exclude -RootPath $rootPath | Should -Be $false
        }
    }
}

Describe "TreeItem Recursion" {
    It "Does not recurse into files" {
        InModuleScope ShowTree -Parameters @{ FixtureScripts = $script:FixtureScripts } {
            param( [string[]] $FixtureScripts ); foreach ($script in $FixtureScripts) { . $script }

            $item = New-TestItem -Name "file.txt" -IsContainer $false
            Test-TreeItemRecurse -Item $item | Should -Be $false
        }
    }

    It "Does not recurse into links if FollowLinks is false" {
        InModuleScope ShowTree -Parameters @{ FixtureScripts = $script:FixtureScripts } {
            param( [string[]] $FixtureScripts ); foreach ($script in $FixtureScripts) { . $script }

            $item = New-TestItem -Name "link"

            # Manually create a link using New-TreeItem since New-TestItem does not have link support
            # $name = "link"
            # $fullPath = Join-Path ($IsWindows ? 'C:\Test' : '/tmp/test') $name
            # $isContainer = $true
            # $kind = 'Symlink'
            # $link = [PSCustomObject]@{
            #     Type = 'SymbolicLink'
            #     Target = $IsWindows ? 'C:\Test' : '/tmp/test'
            #     TargetPath = $IsWindows ? 'C:\Test' : '/tmp/test'
            #     IsBroken = $false
            # }
            # $item = New-TreeItem `
            #     -FullPath $fullPath `
            #     -IsContainer $isContainer `
            #     -Kind $kind `
            #     -Link $link

            # Manually mark as link and container since New-TestItem does not have link support
            $item | Add-Member -MemberType NoteProperty -Name IsContainer -Value $true -Force
            $item | Add-Member -MemberType NoteProperty -Name IsLink -Value $true -Force
            
            Test-TreeItemRecurse -Item $item -FollowLinks:$false | Should -Be $false
            Test-TreeItemRecurse -Item $item -FollowLinks:$true | Should -Be $true
        }
    }

    It "Prunes traversal for excluded directories" {
        InModuleScope ShowTree -Parameters @{ FixtureScripts = $script:FixtureScripts } {
            param( [string[]] $FixtureScripts ); foreach ($script in $FixtureScripts) { . $script }

            $item = New-TestItem -Name "node_modules" -IsContainer $true
            Test-TreeItemRecurse -Item $item -Exclude "node_modules" | Should -Be $false
        }
    }

    It "Does NOT prune traversal for directories that don't match Include" {
        InModuleScope ShowTree -Parameters @{ FixtureScripts = $script:FixtureScripts } {
            param( [string[]] $FixtureScripts ); foreach ($script in $FixtureScripts) { . $script }

            $item = New-TestItem -Name "src" -IsContainer $true

            # Manually mark as container and hidden since New-TestItem does not have support
            $item | Add-Member -MemberType NoteProperty -Name IsContainer -Value $true -Force

            # We want *.ps1 files, 'src' doesn't match but we must recurse to find them
            Test-TreeItemRecurse -Item $item -Include "*.ps1" | Should -Be $true
        }
    }

    It "Prunes traversal for hidden directories unless rescued" {
        InModuleScope ShowTree -Parameters @{ FixtureScripts = $script:FixtureScripts } {
            param( [string[]] $FixtureScripts ); foreach ($script in $FixtureScripts) { . $script }

            $item = New-TestItem -Name ".config"

            # Manually mark as container and hidden since New-TestItem does not have support
            $item | Add-Member -MemberType NoteProperty -Name IsContainer -Value $true -Force
            $item | Add-Member -MemberType NoteProperty -Name Native -Value ([PSCustomObject]@{
                FileAttributes = [IO.FileAttributes]::Hidden
            }) -Force

            Test-TreeItemRecurse -Item $item -HideHidden | Should -Be $false
            Test-TreeItemRecurse -Item $item -HideHidden -Include ".config" | Should -Be $true
        }
    }
}
