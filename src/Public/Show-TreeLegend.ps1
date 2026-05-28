# src/Public/Show-TreeLegend.ps1

<#
.SYNOPSIS
    Displays a color legend for all base types and attribute overlays.

.DESCRIPTION
    Useful for understanding how Show-Tree applies color to files,
    directories, symlinks, junctions, and attribute combinations.
#>
function Show-TreeLegend {
    param(
        $StyleProfile = $null,
        [string]$Culture
    )

    if ($Culture) {
        $StyleProfile = Get-ShowTreeStyleProfile -Culture $Culture
    }
    elseif (-not $StyleProfile) {
        $StyleProfile = Get-ActiveShowTreeStyleProfile
    }

    $reset = $StyleProfile.Reset

    $ui = $StyleProfile.UIStrings.Legend
    Write-Output ""
    Write-Output $ui.Header
    Write-Output $ui.HeaderUnderline
    Write-Output ""

    #
    # Helper to render a sample line
    #
    function Show-Sample {
        param(
            [string]$Name,
            $Item,
            $Indent = "",
            $StyleProfile
        )

        $style = Get-ItemStyle -Item $Item -Colorize:$true -StyleProfile $StyleProfile
        $ansi  = $style.Ansi
        $reset = $StyleProfile.Reset
        Write-Output ("{0,-22} {1}{2}{3}" -f ($Indent + $Name), $ansi, $Name, $reset)
    }

    function ConvertTo-LegendFileAttributes {
        param(
            [Parameter(Mandatory)]
            [string] $Name,

            $StyleProfile
        )

        if ($Name -eq 'None') {
            return [IO.FileAttributes] 0
        }

        try {
            return [IO.FileAttributes] [System.Enum]::Parse([IO.FileAttributes], $Name, $true)
        }
        catch {
            $err = $StyleProfile.UIStrings.Errors.InvalidAttribute -f $Name
            throw $err
        }
    }

    #
    # Base types
    #
    Write-Output $ui.Types

    Show-Sample "File"      (New-TreeItem -FullPath 'file' -IsContainer $false -Kind 'File' -Native @{ FileAttributes = [IO.FileAttributes]::Archive }) " " $StyleProfile
    Write-Output $ui.Attributes
    foreach ($attr in $StyleProfile.Attributes.Keys) {
        $flag = ConvertTo-LegendFileAttributes -Name $attr -StyleProfile $StyleProfile
        $item = New-TreeItem -FullPath 'file' -IsContainer $false -Kind 'File' -Native @{ FileAttributes = $flag }
        Show-Sample $attr $item "   " $StyleProfile
    }
    Write-Output ""

    Show-Sample "Directory" (New-TreeItem -FullPath 'dir' -IsContainer $true -Kind 'Directory' -Native @{ FileAttributes = [IO.FileAttributes]::Directory }) " " $StyleProfile
    Write-Output $ui.Attributes
    foreach ($attr in $StyleProfile.Attributes.Keys) {
        $flag = ConvertTo-LegendFileAttributes -Name $attr -StyleProfile $StyleProfile
        $item = New-TreeItem -FullPath 'dir' -IsContainer $true -Kind 'Directory' -Native @{ FileAttributes = $flag }
        Show-Sample $attr $item "   " $StyleProfile
    }
    Write-Output ""

}
