# src\Public\Show-TreeNew.ps1

<#
.SYNOPSIS
    Displays a directory tree in Normal, Tree.com-compatible, or Listing mode. (Internal/Candidate for 2.0.0)
.DESCRIPTION
    Wrapper for Show-Tree functionality, intended to replace the existing Show-Tree.
#>
function Show-TreeNew {
    [CmdletBinding()]
    param(
        #
        # MODE SELECTION
        #
        [ValidateSet('Normal','Tree','List')]
        [string]$Mode = 'Normal',

        # Backward-compatible aliases
        [Alias('Tree')]
        [switch]$AsTree,

        [Alias('List','Listing')]
        [switch]$AsListing,


        #
        # PATH
        #
        [Parameter(Position = 0)]
        [string]$Path = ".",


        #
        # GLOB FILTERING
        #
        [string[]]$Include,
        [string[]]$Exclude,

        #
        # MODE-SPECIFIC SWITCHES
        #

        # Colorization
        [switch]$Color,      # Tree
        [Alias('NoColor')]
        [switch]$Mono,       # Normal/Listing

        # Files
        [Alias('ShowFiles')]
        [switch]$Files,      # Tree
        [switch]$NoFiles,    # Normal/Listing

        # Hidden
        [switch]$ShowHidden, # Tree
        [switch]$HideHidden, # Normal/Listing

        # System
        [switch]$ShowSystem, # Tree
        [switch]$HideSystem, # Normal/Listing

        # Reparse targets
        [switch]$ShowTargets, # Listing
        [switch]$NoTargets,   # Normal/Tree

        # Gap lines
        [switch]$NoGap,       # Normal/Tree

        # Depth
        [Alias('Depth')]
        [int]$MaxDepth,
        [switch]$Recurse,

        # ASCII connectors
        [switch]$Ascii,

        # Debugging
        [switch]$DebugAttributes,

        # Show the color legend
        [switch]$Legend
    )

    #
    # Legend mode: no tree rendering
    #
    if ($Legend) {
        Show-TreeLegend
        return
    }

    #
    # Resolve Mode (explicit or implied)
    #
    if ($AsTree)    { $Mode = 'Tree' }
    if ($AsListing) { $Mode = 'List' }

    if ($Mode -eq 'Tree' -and $PSVersionTable.PSEdition -eq 'Core' -and -not $IsWindows) {
        throw "ShowTree currently supports Windows only for Tree mode."
    }

    #
    # Validate paired switches
    #
    if ($Color -and $Mono) { throw "Cannot specify both -Color and -Mono." }
    if ($Files -and $NoFiles) { throw "Cannot specify both -Files (or -ShowFiles) and -NoFiles." }
    if ($ShowHidden -and $HideHidden) { throw "Cannot specify both -ShowHidden and -HideHidden." }
    if ($ShowSystem -and $HideSystem) { throw "Cannot specify both -ShowSystem and -HideSystem." }
    if ($ShowTargets -and $NoTargets) { throw "Cannot specify both -ShowTargets and -NoTargets." }

    #
    # Resolve the path
    #
    $resolvedPath = Resolve-TreePath -Path $Path -Mode $Mode
    if (-not $resolvedPath) { return }

    #
    # Compute effective settings
    #
    switch ($Mode) {
        'Tree' {
            $EffectiveMaxDepth    = $PSBoundParameters.ContainsKey('MaxDepth') ? $MaxDepth : -1
            $EffectiveColorize    = $Color.IsPresent
            $EffectiveFiles       = $Files.IsPresent
            $EffectiveHideHidden  = -not $ShowHidden.IsPresent
            $EffectiveHideSystem  = -not $ShowSystem.IsPresent
            $EffectiveShowTargets = -not $NoTargets.IsPresent
            $EffectiveGap         = -not $NoGap.IsPresent
        }
        'List' {
            $EffectiveMaxDepth    = $PSBoundParameters.ContainsKey('MaxDepth') ? $MaxDepth : -1
            $EffectiveColorize    = -not $Mono.IsPresent
            $EffectiveFiles       = -not $NoFiles.IsPresent
            $EffectiveHideHidden  = $HideHidden.IsPresent
            $EffectiveHideSystem  = $HideSystem.IsPresent
            $EffectiveShowTargets = $ShowTargets.IsPresent
            $EffectiveGap         = $false
        }
        'Normal' {
            $EffectiveMaxDepth    = $Recurse.IsPresent ? -1 : ($PSBoundParameters.ContainsKey('MaxDepth') ? $MaxDepth : 6)
            $EffectiveColorize    = -not $Mono.IsPresent
            $EffectiveFiles       = -not $NoFiles.IsPresent
            $EffectiveHideHidden  = $HideHidden.IsPresent
            $EffectiveHideSystem  = $HideSystem.IsPresent
            $EffectiveShowTargets = -not $NoTargets.IsPresent
            $EffectiveGap         = -not $NoGap.IsPresent
        }
    }

    #
    # Header Rendering
    #
    if ($Mode -eq 'Tree') {
        $header = Get-TreeModeHeader -Path $resolvedPath
        $header | Where-Object { $_ -is [string] }
        if ($header -contains $false) {
            return
        }
    }
    else {
        # Normal + Listing modes: Print resolved path with style
        $rootItem = Get-Item $resolvedPath
        $native = [PSCustomObject]@{
            Platform = if ($IsWindows) { 'Windows' } else { 'Unix' }
            FileAttributes = $rootItem.Attributes
        }
        $kind = if ($rootItem.PSIsContainer) { 'Directory' } else { 'File' }
        $treeItem = New-TreeItem `
            -FullPath $rootItem.FullName `
            -IsContainer $rootItem.PSIsContainer `
            -Kind $kind `
            -Name $rootItem.Name `
            -Native $native `
            -Depth 0

        $resolvedStyleProfile = Get-ActiveShowTreeStyleProfile
        if ($null -eq $resolvedStyleProfile) { $resolvedStyleProfile = Get-ShowTreeStyleProfile }

        $style = Get-ItemStyle -Item $treeItem -Colorize:$EffectiveColorize -StyleProfile $resolvedStyleProfile

        $debug = ""
        if ($DebugAttributes) {
            $styleName = $style.Name
            $attributes = $treeItem.Native.FileAttributes
            $attrHex   = if ($null -ne $attributes) { ('0x{0:X8}' -f [uint32]$attributes) } else { "n/a" }
            $attrNames = if ($null -ne $attributes) { $attributes.ToString() } else { "n/a" }
            $debug     = " [$attrHex $attrNames | $styleName]"
        }

        $esc = [char]27
        $colorReset = $EffectiveColorize ? "${esc}[0m" : ""
        Write-Output "$($style.Ansi)$resolvedPath${colorReset}${debug}"
    }

    # Initialize gap state machine
    $script:GapState = [PSCustomObject]@{
        LastGapMode = [GapMode]::None
    }

    $resolvedStyleProfile = Get-ActiveShowTreeStyleProfile
    if ($null -eq $resolvedStyleProfile) { $resolvedStyleProfile = Get-ShowTreeStyleProfile }

    #
    # Delegate to internal engine
    #
    Show-TreeInternal `
        -Path          $resolvedPath `
        -Mode          $Mode `
        -MaxDepth      $EffectiveMaxDepth `
        -Colorize:$EffectiveColorize `
        -IncludeFiles:$EffectiveFiles `
        -HideHidden:$EffectiveHideHidden `
        -HideSystem:$EffectiveHideSystem `
        -ShowTargets:$EffectiveShowTargets `
        -Exclude $Exclude `
        -Include $Include `
        -Gap:$EffectiveGap `
        -Ascii:$Ascii `
        -DebugAttributes:$DebugAttributes `
        -StyleProfile  $resolvedStyleProfile

    #
    # Footer / Last Line logic
    #
    if ($Mode -ne 'Tree') {
        Write-Output ""
    }
}
