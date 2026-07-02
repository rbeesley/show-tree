# src/Private/Rendering/Get-ItemStyle.ps1

<#
.SYNOPSIS
    Computes the ANSI style for a file or directory.

.DESCRIPTION
    The Get-ItemStyle cmdlet determines the color and styling for an item based on its type 
    (File or Directory) and its states (Hidden, System, Symlink, etc.). 
    
    It performs a multi-pass resolution:
    1. Selects the base style (File vs Directory).
    2. Overlays styles for active states (e.g., Dim for Hidden).
    3. Resolves Foreground/Background overrides based on the profile's StylePriority.
    
    Returns a PSCustomObject containing the resolved ANSI escape sequence.

.PARAMETER Item
    The ShowTree.TreeItem to style.

.PARAMETER Colorize
    If true, returns ANSI escape sequences. If false, returns empty strings.

.PARAMETER StyleProfile
    The style profile object containing the color definitions.
#>
function Get-ItemStyle {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object] $Item,

        [Parameter(Mandatory)]
        [bool] $Colorize,

        [object] $StyleProfile = $null
    )

    if (-not $PSBoundParameters.ContainsKey('Debug') -and $PSCmdlet)
    {
        $DebugPreference = $PSCmdlet.GetVariableValue('DebugPreference')
    }
    if (-not $PSBoundParameters.ContainsKey('Verbose') -and $PSCmdlet)
    {
        $VerbosePreference = $PSCmdlet.GetVariableValue('VerbosePreference')
    }

    $StyleProfile ??= Get-ActiveShowTreeStyleProfile

    $esc = $StyleProfile.Esc

    $isContainer = $Item.IsContainer
    $attrs       = $Item.Native.FileAttributes

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

    # Extract foreground codes.
    # Includes:
    #   30-37  standard foreground colors
    #   90-97  bright foreground colors
    #   39     terminal default foreground
    #
    # 39 must be treated as a foreground code so it does not remain in the
    # non-foreground code list and reset later OverrideForeground values.
    $fgList = [System.Collections.Generic.List[object]]::new()
    $remainingCodes = [System.Collections.Generic.List[object]]::new()
    foreach ($c in $codesList) {
        if ($c -match '^(3[0-7]|9[0-7]|39)$') { [void]$fgList.Add($c) }
        else { [void]$remainingCodes.Add($c) }
    }
    $fg = $fgList.ToArray()
    $codes = $remainingCodes

    #
    # Apply States
    #
    # 1. Start with explicit States from the item
    # 2. Add States derived from Native FileAttributes for Windows/provider support
    #
    $allStates = [System.Collections.Generic.List[string]]::new()
    if ($Item.States) {
        foreach ($s in $Item.States) { [void]$allStates.Add($s) }
    }

    # Derive states from Native FileAttributes.
    if ($attrs) {
        foreach ($flag in Get-FileAttributes $attrs) {
            $flagName = $flag.ToString()
            if (-not $allStates.Contains($flagName)) { [void]$allStates.Add($flagName) }
        }
    }

    # Apply broad/low-priority styles first and specific/high-priority
    # styles last. Later Foreground/Background values intentionally win.
    $stateStylePriority = @($StyleProfile.StylePriority)

    $knownStates = [System.Collections.Generic.List[string]]::new()
    foreach ($priorityState in $stateStylePriority) {
        if ($allStates.Contains($priorityState)) {
            [void]$knownStates.Add($priorityState)
        }
    }

    $customStates = [System.Collections.Generic.List[string]]::new()
    foreach ($stateName in $allStates) {
        if ($stateStylePriority -notcontains $stateName) {
            [void]$customStates.Add($stateName)
        }
    }

    $orderedStates = [System.Collections.Generic.List[string]]::new()
    $orderedStates.AddRange($knownStates)
    $orderedStates.AddRange($customStates)

    # Lookup styles from States.
    foreach ($stateName in $orderedStates) {
        $overlay = $null

        if ($StyleProfile.States -and $StyleProfile.States.ContainsKey($stateName)) {
            $overlay = $StyleProfile.States[$stateName]
        }

        if ($overlay) {
            # Add state style SGR fragments.
            $ansiStyle = $overlay.AnsiStyle
            if ($ansiStyle) {
                foreach ($a in ($ansiStyle -split ';')) {
                    if ($a -ne '' -and $codes -notcontains $a) { [void]$codes.Add($a) }
                }
            }

            # Foreground override.
            if ($overlay.Foreground) {
                if ($overlay.Foreground -is [string]) {
                    $fg = $overlay.Foreground
                }
                elseif ($overlay.Foreground.ContainsKey($styleName)) {
                    $fg = $overlay.Foreground[$styleName]
                }
            }

            # Background override.
            if ($overlay.Background) {
                [void]$codes.Add($overlay.Background)
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