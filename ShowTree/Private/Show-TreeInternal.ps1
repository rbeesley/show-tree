# Show-Tree\Private\Show-TreeInternal.ps1

#region Entry Point
<#
.SYNOPSIS
    Core recursive engine for Show-Tree.

.DESCRIPTION
    This function renders a directory tree using graphical connectors,
    optional color, optional file inclusion, and optional gap logic.
    It is called once from Show-Tree.ps1 and then recursively by itself.

    Responsibilities:
      • Normalize and validate the root path
      • Initialize gap state
      • Enumerate directories/files (raw Win32 or PowerShell)
      • Applies stable-order filtering using Get-FilteredTreeItems
        (Hidden/System/Include/Exclude with exact/glob precedence)
      • Render files, directories, and gap lines
      • Manage recursion depth and prefix construction
      • Maintain gap-mode state machine (Internal, Tail, Sibling)

    This function is internal-only and not exported.
#>
enum GapMode {
    None
    Internal
    Tail
    Sibling
}

function Show-TreeInternal {
    [CmdletBinding()]
    param (
        # Absolute or relative path to render
        [string]$Path,

        # Output mode
        [ValidateSet('Normal','Tree','List')]
        [string]$Mode = 'Normal',

        # Maximum recursion depth (-1 = unlimited)
        [int]$MaxDepth = -1,

        # Enable color output
        [switch]$Colorize,

        # Include files in output
        [switch]$IncludeFiles,

        # Hide hidden items
        [switch]$HideHidden,

        # Hide system items
        [switch]$HideSystem,

        # Show reparse point targets
        [switch]$ShowTargets,

        # Glob-based include/exclude filtering
        [string[]]$Exclude,
        [string[]]$Include,

        # Enable gap logic (blank lines between blocks)
        [switch]$Gap,

        # Use ASCII connectors instead of Unicode
        [switch]$Ascii,

        # Show attribute debug info
        [switch]$DebugAttributes,

        # Current recursion depth (internal)
        [int]$CurrentDepth = 0,

        # Prefix string built from parent connectors
        [string]$Prefix = "",

        # Whether the parent directory was the last sibling
        [bool]$IsLastParent = $false
    )

    #
    # Depth cap enforcement
    #
    if ($MaxDepth -ne -1 -and $CurrentDepth -ge $MaxDepth) {
        return
    }

    #
    # Directory enumeration
    #
    if ($Mode -eq 'Tree') {
        # Raw Win32 enumeration for Tree.com compatibility
        $raw   = Get-RawDirectoryEntries -Path $Path
        $files = $IncludeFiles ? $raw.Files : @()
        $dirs  = $raw.Directories
    }
    else {
        # Standard PowerShell enumeration
        $files = $IncludeFiles ? (Get-ChildItem -Path $Path -File -Force -ErrorAction SilentlyContinue) : @()
        $dirs  = Get-ChildItem -Path $Path -Directory -Force -ErrorAction SilentlyContinue
    }

    #
    # Filtering
    #
    $dirs  = Get-FilteredTreeItems -Items $dirs  -Include $Include -Exclude $Exclude -HideHidden:$HideHidden -HideSystem:$HideSystem
    $files = Get-FilteredTreeItems -Items $files -Include $Include -Exclude $Exclude -HideHidden:$HideHidden -HideSystem:$HideSystem

    $fileCount = $files.Count
    $dirCount  = $dirs.Count

    # Tree.com: suppress file connectors when no subdirectories exist
    $noSpan = $Mode -eq 'Tree' -and $dirCount -eq 0

    #
    # FILE RENDERING
    #
    for ($j = 0; $j -lt $fileCount; $j++) {
        $file       = $files[$j]
        $isLastFile = ($j -eq $fileCount - 1) -and ($dirCount -eq 0)

        Write-TreeItem `
            -Item          $file `
            -Type          File `
            -Prefix        $Prefix `
            -IsLast        $isLastFile `
            -Mode          $Mode `
            -Ascii:$Ascii `
            -Colorize:$Colorize `
            -ShowTargets:$ShowTargets `
            -DebugAttributes:$DebugAttributes `
            -Recurse:$false `
            -NoSpan        $noSpan `
            -MaxDepth      $MaxDepth `
            -CurrentDepth  $CurrentDepth `
            -IncludeFiles:$IncludeFiles `
            -Include       $Include `
            -Exclude       $Exclude `
            -Gap:$Gap `
            -HideHidden:$HideHidden `
            -HideSystem:$HideSystem
    }

    #
    # INTERNAL GAP (files → directories)
    #

    # Precompute ANSI sequences
    $esc        = [char]27
    $colorReset = $Colorize ? "${esc}[0m"  : ""
    $colorGap   = $Colorize ? "${esc}[90m" : ""

    # Precompute gap connector
    $gapConnector = Get-Connector -Type Gap -Mode $Mode -Ascii:$Ascii

    if ($Gap -and
        $script:GapState.LastGapMode -eq [GapMode]::None -and
        $IncludeFiles -and
        $fileCount -gt 0) {

        if ($dirCount -gt 0) {
            # Files + directories → connector gap
            Write-Gap $colorGap $Prefix $gapConnector $colorReset ([GapMode]::Internal)
        }
        else {
            # Files only → tail gap
            if ($Mode -eq 'Tree' -or (-not $IsLastParent)) {
                Write-Gap $colorGap $Prefix $null $colorReset ([GapMode]::Tail)
            }
        }
    }

    #
    # DIRECTORY RENDERING
    #
    for ($i = 0; $i -lt $dirCount; $i++) {
        $dir       = $dirs[$i]
        $isLastDir = ($i -eq $dirCount - 1)

        Write-TreeItem `
            -Item           $dir `
            -Type           Directory `
            -Prefix         $Prefix `
            -IsLast         $isLastDir `
            -Mode           $Mode `
            -Ascii:$Ascii `
            -Colorize:$Colorize `
            -ShowTargets:$ShowTargets `
            -DebugAttributes:$DebugAttributes `
            -Recurse `
            -NoSpan         $false `
            -MaxDepth       $MaxDepth `
            -CurrentDepth   $CurrentDepth `
            -IncludeFiles:$IncludeFiles `
            -Include       $Include `
            -Exclude       $Exclude `
            -Gap:$Gap `
            -HideHidden:$HideHidden `
            -HideSystem:$HideSystem

        #
        # SIBLING / COUSIN GAP LOGIC
        #
        if ($Gap -and $i -lt $dirCount - 1) {

            # Tail gap suppresses immediate sibling gap
            if ($script:GapState.LastGapMode -eq [GapMode]::Tail) {
                $script:GapState.LastGapMode = [GapMode]::None
                continue
            }

            # Prevent consecutive gaps
            if ($script:GapState.LastGapMode -ne [GapMode]::None) {
                continue
            }

            # Normal mode: only if left sibling has visible children
            if ($Mode -ne 'Tree') {
                if (Test-HasChildrenForGap -Dir $dirs[$i] -CurrentDepth $CurrentDepth -MaxDepth $MaxDepth) {
                    Write-Gap $colorGap $Prefix $gapConnector $colorReset ([GapMode]::Sibling)
                }
            }
        }
    }
}
#endregion
