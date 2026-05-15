# src\Public\Show-TreeLegend.ps1

<#
.SYNOPSIS
    Displays a color legend for all base types and attribute overlays.

.DESCRIPTION
    Useful for understanding how Show-Tree applies color to files,
    directories, symlinks, junctions, and attribute combinations.
#>
function Show-TreeLegend {
    param(
        $StyleProfile = $null
    )

    $StyleProfile = if (-not $StyleProfile) {
        Get-ActiveShowTreeStyleProfile
    } else {
        $StyleProfile
    }

    $esc   = [char]27
    $reset = "${esc}[0m"

    Write-Output ""
    Write-Output "Legend"
    Write-Output "------"
    Write-Output ""

    #
    # Helper to render a sample line
    #
    function Show-Sample {
        param(
            [string]$Name,
            $Item,
            $Indent = ""
        )

        $style = Get-ItemStyle -Item $Item -Colorize:$true
        $ansi  = $style.Ansi
        Write-Output ("{0,-22} {1}{2}{3}" -f ($Indent + $Name), $ansi, $Name, $reset)
    }

    function ConvertTo-LegendFileAttributes {
        param(
            [Parameter(Mandatory)]
            [string] $Name
        )

        if ($Name -eq 'None') {
            return [IO.FileAttributes] 0
        }

        try {
            return [IO.FileAttributes] [System.Enum]::Parse([IO.FileAttributes], $Name, $true)
        }
        catch {
            throw "Style profile attribute '$Name' is not a valid System.IO.FileAttributes value."
        }
    }

    #
    # Base types
    #
    Write-Output "Types:"

    Show-Sample "File"      ([pscustomobject]@{ PSIsContainer = $false; Attributes = [IO.FileAttributes]::Archive }) " "
    Write-Output "  Attributes:"
    foreach ($attr in $StyleProfile.Attributes.Keys) {
        $flag = ConvertTo-LegendFileAttributes -Name $attr
        $item = [pscustomobject]@{
            PSIsContainer = $false
            Attributes    = $flag
        }
        Show-Sample $attr $item "   "
    }
    Write-Output ""

    Show-Sample "Directory" ([pscustomobject]@{ PSIsContainer = $true;  Attributes = [IO.FileAttributes]::Directory }) " "
    Write-Output "  Attributes:"
    foreach ($attr in $StyleProfile.Attributes.Keys) {
        $flag = ConvertTo-LegendFileAttributes -Name $attr
        $item = [pscustomobject]@{
            PSIsContainer = $true
            Attributes    = $flag
        }
        Show-Sample $attr $item "   "
    }
    Write-Output ""

}
