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

            Test-TreeItemVisible `
                -Item $srcFixtures `
                -Exclude ".\src\TestFixtures\" `
                -RootPath $rootPath |
                    Should -Be $false

            Test-TreeItemVisible `
                -Item $testFixtures `
                -Exclude ".\src\TestFixtures\" `
                -RootPath $rootPath |
                    Should -Be $true
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
