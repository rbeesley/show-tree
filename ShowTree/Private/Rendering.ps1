# ShowTree\Private\Rendering.ps1

#region TreeItem Rendering
<#
.SYNOPSIS
    Renders a single file or directory entry.

.DESCRIPTION
    Handles:
      • Connector selection
      • Style/color application
      • Reparse target display
      • Attribute debug output
      • Recursion into subdirectories
      • Gap-state reset
#>
function Write-TreeItem {
    param(
        [Parameter(Mandatory)]
        $Item,

        [Parameter(Mandatory)]
        [ValidateSet('File','Directory')]
        [string]$Type,

        [ValidateSet('Normal','Tree','List')]
        [string]$Mode = 'Normal',

        # Prefix inherited from parent
        [string]$Prefix = "",

        # Whether this item is the last sibling
        [bool]$IsLast,

        # Mode switches
        [switch]$Ascii,
        [switch]$Colorize,
        [switch]$ShowTargets,
        [switch]$DebugAttributes,
        [switch]$Recurse,

        # Whether to suppress file connector span
        [bool]$NoSpan = $false,

        # Recursion state
        [int]$MaxDepth,
        [int]$CurrentDepth,

        # Additional flags
        [switch]$IncludeFiles,
        [string[]]$Exclude,
        [string[]]$Include,        
        [switch]$Gap,
        [switch]$HideHidden,
        [switch]$HideSystem
    )

    # Compute connector for this item
    $connector = Get-Connector `
        -Type   $Type `
        -Mode   $Mode `
        -Ascii:$Ascii `
        -IsLast $IsLast `
        -NoSpan $NoSpan

    # Compute style
    $style = Get-ItemStyle -Item $Item -Colorize:$Colorize

    #
    # Reparse target resolution
    #
    $target = $null
    if ($ShowTargets -and ($Item.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
        $info = Get-Item -LiteralPath $Item.FullName -Force -ErrorAction SilentlyContinue
        if ($info -and $info.PSObject.Properties.Match('Target')) {
            $target = $info.Target
        }
    }

    #
    # Output formatting
    #
    $esc   = [char]27
    $reset = $Colorize ? "${esc}[0m"  : ""
    $dim   = $Colorize ? "${esc}[90m" : ""

    $targetText = $target ? " ${dim}->${reset} $target" : ""

    # Optional attribute debug
    $debug = ""
    if ($DebugAttributes) {
        $styleName = $style.Name
        $attrHex   = ('0x{0:X8}' -f [uint32]$Item.Attributes)
        $attrNames = $Item.Attributes.ToString()
        $debug     = " [$attrHex $attrNames | $styleName]"
    }

    Write-Output "${dim}${Prefix}${dim}${connector}$($style.Ansi)$($Item.Name)$reset$targetText$debug"

    #
    # Reset gap state unless tail gap was printed
    #
    if ($script:GapState.LastGapMode -ne [GapMode]::Tail) {
        $script:GapState.LastGapMode = [GapMode]::None
    }

    #
    # Recursion into subdirectories
    #
    if ($Recurse -and
        $Type -eq 'Directory' -and
        -not ($Item.Attributes -band [IO.FileAttributes]::ReparsePoint)) {

        # Build next-level prefix
        $newPrefix = $Prefix + (Get-Connector `
            -Type   Prefix `
            -Mode   $Mode `
            -Ascii:$Ascii `
            -IsLast $IsLast)

        # Recurse
        Show-TreeInternal `
            -Path          $Item.FullName `
            -Mode          $Mode `
            -MaxDepth      $MaxDepth `
            -Colorize:$Colorize `
            -IncludeFiles:$IncludeFiles `
            -HideHidden:$HideHidden `
            -HideSystem:$HideSystem `
            -ShowTargets:$ShowTargets `
            -Exclude      $Exclude `
            -Include      $Include `
            -Gap:$Gap `
            -Ascii:$Ascii `
            -DebugAttributes:$DebugAttributes `
            -CurrentDepth  ($CurrentDepth + 1) `
            -Prefix        $newPrefix `
            -IsLastParent  $IsLast
    }

    #
    # Reset gap state again after recursion
    #
    if ($script:GapState.LastGapMode -ne [GapMode]::Tail) {
        $script:GapState.LastGapMode = [GapMode]::None
    }
}
#endregion

#region Gap Rendering
<#
.SYNOPSIS
    Writes a gap line between blocks.

.DESCRIPTION
    Handles Internal, Tail, and Sibling gap modes.
    Updates the global gap-state machine.
#>
function Write-Gap {
    param(
        $colorGap,
        $Prefix,
        $GapConnector,
        $colorReset,
        [GapMode]$Mode
    )

    $connector = $GapConnector ? $GapConnector : ""
    Write-Output "${colorGap}${Prefix}${connector}${colorReset}"
    $script:GapState.LastGapMode = $Mode
}

#region Connector Rendering
<#
.SYNOPSIS
    Returns the connector string for a given item type.

.DESCRIPTION
    Handles:
      • Tree.com ASCII mode
      • Unicode graphical mode
      • Prefix vs File vs Directory vs Gap
      • Last-sibling logic
      • NoSpan suppression for Tree.com file connectors
#>
function Get-Connector {
    param(
        [Parameter(Mandatory)]
        [ValidateSet('File','Directory','Gap','Prefix')]
        [string]$Type,

        [ValidateSet('Normal','Tree','List')]
        [string]$Mode = 'Normal',

        [switch]$Ascii,

        [bool]$IsLast = $false,
        [bool]$NoSpan = $false
    )

    #
    # Listing mode: indentation only
    #
    if ($Mode -eq 'List') {
        return ' '
    }

    #
    # Tree.com compatibility mode
    #
    if ($Mode -eq 'Tree') {
        if ($Type -eq 'File' -and $NoSpan) {
            return '    '
        }

        switch ($Type) {
            'File'      { return $Ascii ? '|   '  : '│   ' }
            'Directory' {
                if ($IsLast) { return $Ascii ? '\---' : '└───' }
                else         { return $Ascii ? '+---' : '├───' }
            }
            'Gap'       { return $Ascii ? '|'    : '│' }
            'Prefix'    {
                if ($IsLast) { return '    ' }
                else         { return $Ascii ? '|   ' : '│   ' }
            }
        }
    }

    #
    # Graphical Unicode mode (Show-Tree default)
    #
    switch ($Type) {
        'File' {
            if ($IsLast) { return $Ascii ? '\-- ' : '╙── ' }
            else         { return $Ascii ? '+-- ' : '╟── ' }
        }

        'Directory' {
            if ($IsLast) { return $Ascii ? '\== ' : '╚══ ' }
            else         { return $Ascii ? '+== ' : '╠══ ' }
        }

        'Gap' {
            return $Ascii ? '|' : '║'
        }

        'Prefix' {
            if ($IsLast) { return '    ' }
            else         { return $Ascii ? '|   ' : '║   ' }
        }
    }
}
#endregion

#region Style Rendering
<#
.SYNOPSIS
    Computes the ANSI style for a file or directory.

.DESCRIPTION
    Applies:
      • Base style (directory/file/symlink/junction)
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
        $StyleProfile = $script:StyleProfile
    )

    $esc = [char]27

    $isDir     = $Item.PSIsContainer
    $attrs     = $Item.Attributes
    $isReparse = [bool]($attrs -band [IO.FileAttributes]::ReparsePoint)

    #
    # Determine base style
    #
    if ($isReparse -and $isDir) {
        $styleName = "Junction"
        $base      = $StyleProfile.Base.Junction
    }
    elseif ($isReparse -and -not $isDir) {
        $styleName = "Symlink"
        $base      = $StyleProfile.Base.File
    }
    elseif ($isDir) {
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
#endregion