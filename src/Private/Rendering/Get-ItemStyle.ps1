# src/Private/Rendering/Get-ItemStyle.ps1

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

    $esc = $StyleProfile.Esc

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
    $codesList = [System.Collections.Generic.List[object]]::new()
        foreach ($c in ($base -split ';')) {
            if ($c -ne '') { [void]$codesList.Add($c) }
        }

    # Extract foreground codes (30–37, 90–97)
    $fgList = [System.Collections.Generic.List[object]]::new()
    $remainingCodes = [System.Collections.Generic.List[object]]::new()
    foreach ($c in $codesList) {
        if ($c -match '^(3[0-7]|9[0-7])$') { [void]$fgList.Add($c) }
        else { [void]$remainingCodes.Add($c) }
    }
    $fg = $fgList.ToArray()
    $codes = $remainingCodes

    #
    # Apply attribute overlays
    #
    if ($null -ne $attrs -and $null -ne $StyleProfile.Attributes) {
        foreach ($flag in Get-SetFileAttributes $attrs) {
            $flagName = $flag.ToString()
            
            if ($StyleProfile.Attributes.ContainsKey($flagName)) {
                $overlay = $StyleProfile.Attributes[$flagName]

                # Add overlay attributes
                if ($overlay.Attributes) {
                    foreach ($a in ($overlay.Attributes -split ';')) { [void]$codes.Add($a) }
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
    $final = [System.Collections.Generic.List[object]]::new()
    if ($fg) {
        if ($fg -is [array]) { foreach ($f in $fg) { [void]$final.Add($f) } }
        else { [void]$final.Add($fg) }
    }
    foreach ($c in $codes) { [void]$final.Add($c) }

    $ansi = "${esc}[$($final -join ';')m"

    [PSCustomObject]@{
        Name = $styleName
        Ansi = $ansi
    }
}
