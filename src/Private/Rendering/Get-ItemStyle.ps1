# src\Private\Rendering\Get-ItemStyle.ps1

<#
.SYNOPSIS
    Computes the ANSI style for a file or directory.

.DESCRIPTION
    Applies:
      • Base style (directory/file)
      • Attribute overlays (hidden, system, temporary, etc.)
      • Foreground overrides
      • Combined ANSI escape sequence

    Returns an object:
      @{ Name = "..."; Ansi = "..."; }
#>
function Get-ItemStyle {
    param(
        $Item,
        $Colorize,
        $StyleProfile = $null
    )

    $StyleProfile = if (-not $StyleProfile) {
        Get-ActiveShowTreeStyleProfile
    } else {
        $StyleProfile
    }

    $esc = [char]27

    $isContainer = $Item.IsContainer
    $attrs       = $Item.Native.FileAttributes
    $kind        = $Item.Kind

    #
    # Determine base style
    #
    if ($isContainer) {
        $styleName = "Directory"
        $base      = $StyleProfile.Base.Directory
    }
    else {
        $styleName = "File"
        $base      = $StyleProfile.Base.File
    }

    #
    # No color mode
    #
    if (-not $Colorize) {
        return [PSCustomObject]@{
            Name = $styleName
            Ansi = ""
        }
    }

    #
    # Parse base style codes
    #
    $codes = @() + ($base -split ';' | Where-Object { $_ -ne '' })

    # Extract foreground codes (30–37, 90–97)
    $fg    = @() + ($codes | Where-Object { $_ -match '^(3[0-7]|9[0-7])$' })
    $codes = @() + ($codes | Where-Object { $_ -notmatch '^(3[0-7]|9[0-7])$' })

    #
    # Apply attribute overlays
    #
    if ($attrs -ne $null -and $StyleProfile.Attributes -ne $null) {
        foreach ($flag in Get-SetFileAttributes $attrs) {
            $flagName = $flag.ToString()
            
            if ($StyleProfile.Attributes.ContainsKey($flagName)) {
                $overlay = $StyleProfile.Attributes[$flagName]

                # Add overlay attributes
                if ($overlay.Attributes) {
                    $codes += ($overlay.Attributes -split ';')
                }

                # Foreground override
                if ($overlay.OverrideForeground) {
                    if ($overlay.OverrideForeground -is [string]) {
                        $fg = $overlay.OverrideForeground
                    }
                    elseif ($overlay.OverrideForeground.ContainsKey($styleName)) {
                        $fg = $overlay.OverrideForeground[$styleName]
                    }
                }
            }
        }
    }

    #
    # Build final ANSI sequence
    #
    $final = @()
    if ($fg) { $final += $fg }
    $final += $codes

    $ansi = "${esc}[$($final -join ';')m"

    [PSCustomObject]@{
        Name = $styleName
        Ansi = $ansi
    }
}
