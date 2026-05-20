# src\Tests\Unit\Filtering\Filtering.Tests.ps1

BeforeAll {
    $script:ModuleUnderTest = . "$PSScriptRoot\..\..\Helpers\Import-ModuleUnderTest.ps1" `
        -StartPath $PSScriptRoot `
        -ModuleName 'ShowTree' `
        -SourceRootName 'src' `
        -Exclude 'src/Tests/*' `
        -PassThru
}

Describe "TreeItem Visibility" {
    It "Excludes exact matches" {
        InModuleScope ShowTree {
            . "$PSScriptRoot\..\..\Helpers\PrivateHelpers.ps1"

            $item = New-TestItem -Name ".git"
            $visible = Test-TreeItemVisible -Item $item -Exclude ".git"
            $visible | Should -Be $false

            $item2 = New-TestItem -Name ".github"
            $visible2 = Test-TreeItemVisible -Item $item2 -Exclude ".git"
            $visible2 | Should -Be $true
        }
    }

    It "Glob include resurrects items excluded by glob" {
        InModuleScope ShowTree {
            . "$PSScriptRoot\..\..\Helpers\PrivateHelpers.ps1"

            $item = New-TestItem -Name ".github"
            $visible = Test-TreeItemVisible -Item $item -Exclude ".*" -Include ".github"
            $visible | Should -Be $true

            $item2 = New-TestItem -Name ".git"
            $visible2 = Test-TreeItemVisible -Item $item2 -Exclude ".*" -Include ".github"
            $visible2 | Should -Be $false
        }
    }

    It "Exact exclude beats glob include" {
        InModuleScope ShowTree {
            . "$PSScriptRoot\..\..\Helpers\PrivateHelpers.ps1"

            $item = New-TestItem -Name ".git"
            $visible = Test-TreeItemVisible -Item $item -Exclude ".git" -Include ".git*"
            $visible | Should -Be $false

            $item2 = New-TestItem -Name ".gitignore"
            $visible2 = Test-TreeItemVisible -Item $item2 -Exclude ".git" -Include ".git*"
            $visible2 | Should -Be $true
        }
    }

    It "Include resurrects hidden items" {
        InModuleScope ShowTree {
            . "$PSScriptRoot\..\..\Helpers\PrivateHelpers.ps1"

            $item = New-TestItem -Name ".config" -Attributes ([IO.FileAttributes]::Hidden)
            $visible = Test-TreeItemVisible -Item $item -HideHidden -Include ".config"
            $visible | Should -Be $true
        }
    }
}

Describe "TreeItem Recursion" {
    It "Does not recurse into files" {
        InModuleScope ShowTree {
            . "$PSScriptRoot\..\..\Helpers\PrivateHelpers.ps1"
            $item = New-TestItem -Name "file.txt" -IsContainer $false
            Test-TreeItemRecurse -Item $item | Should -Be $false
        }
    }

    It "Does not recurse into links if FollowLinks is false" {
        InModuleScope ShowTree {
            . "$PSScriptRoot\..\..\Helpers\PrivateHelpers.ps1"

            $item = New-TestItem -Name "link"

            # Manually mark as link and container since New-TestItem does not have link support
            $item | Add-Member -MemberType NoteProperty -Name IsContainer -Value $true -Force
            $item | Add-Member -MemberType NoteProperty -Name IsLink -Value $true -Force
            
            # Manually create a link using New-TreeItem since New-TestItem does not have link support
            # $name = "link"
            # $fullPath = Join-Path ($IsWindows ? 'C:\Test' : '/tmp/test') $name
            # $isContainer = $true
            # $kind = 'Symlink'
            # $link = [PSCustomObject]@{
            #     Type = 'SymbolicLink'
            #     Target = if ($IsWindows) { 'C:\Target' } else { '/tmp/target' }
            #     TargetPath = if ($IsWindows) { 'C:\Target' } else { '/tmp/target' }
            #     IsBroken = $false
            # }
            # $item = New-TreeItem `
            #     -FullPath $fullPath `
            #     -IsContainer $isContainer `
            #     -Kind $kind `
            #     -Link $link

            Test-TreeItemRecurse -Item $item -FollowLinks:$false | Should -Be $false
            Test-TreeItemRecurse -Item $item -FollowLinks:$true | Should -Be $true
        }
    }

    It "Prunes traversal for excluded directories" {
        InModuleScope ShowTree {
            . "$PSScriptRoot\..\..\Helpers\PrivateHelpers.ps1"
            $item = New-TestItem -Name "node_modules" -IsContainer $true
            Test-TreeItemRecurse -Item $item -Exclude "node_modules" | Should -Be $false
        }
    }

    It "Does NOT prune traversal for directories that don't match Include" {
        InModuleScope ShowTree {
            . "$PSScriptRoot\..\..\Helpers\PrivateHelpers.ps1"
            $item = New-TestItem -Name "src" -IsContainer $true

            # Manually mark as container and hidden since New-TestItem does not have support
            $item | Add-Member -MemberType NoteProperty -Name IsContainer -Value $true -Force

            # We want *.ps1 files, 'src' doesn't match but we must recurse to find them
            Test-TreeItemRecurse -Item $item -Include "*.ps1" | Should -Be $true
        }
    }

    It "Prunes traversal for hidden directories unless rescued" {
        InModuleScope ShowTree {
            . "$PSScriptRoot\..\..\Helpers\PrivateHelpers.ps1"
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
