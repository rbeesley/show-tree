# src\Private\Rendering\Write-TreeItem.ps1

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
    if ($ShowTargets -and $Item.IsLink) {
        if ($Item.Link.Target) {
            $target = $Item.Link.Target
        }
        else {
            # Fallback for partially populated Link objects
            $info = Get-Item -LiteralPath $Item.FullPath -Force -ErrorAction SilentlyContinue
            if ($info -and $info.PSObject.Properties.Match('Target')) {
                $target = $info.Target
            }
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
        $attributes = $Item.Native.FileAttributes
        $attrHex   = if ($attributes -ne $null) { ('0x{0:X8}' -f [uint32]$attributes) } else { "n/a" }
        $attrNames = if ($attributes -ne $null) { $attributes.ToString() } else { "n/a" }
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
        $Item.IsDirectory -and
        -not $Item.IsLink) {

        # Build next-level prefix
        $newPrefix = $Prefix + (Get-Connector `
            -Type   Prefix `
            -Mode   $Mode `
            -Ascii:$Ascii `
            -IsLast $IsLast)

        # Recurse
        Show-TreeInternal `
            -Path          $Item.FullPath `
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
