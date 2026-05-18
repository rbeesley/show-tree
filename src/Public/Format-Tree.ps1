function Format-Tree {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline, Mandatory)]
        [object[]]$Items,

        [ValidateSet('Normal', 'Tree', 'List')]
        [string]$Mode = 'Normal',

        [switch]$Ascii,
        [switch]$Colorize,
        [switch]$ShowTargets,
        [switch]$NoGap,
        [object]$StyleProfile
    )

    begin {
        $Gap = -not $NoGap.IsPresent
        $resolvedStyleProfile = if ($null -ne $StyleProfile) {
            if ($StyleProfile -is [string]) { Get-ShowTreeStyleProfile -Path $StyleProfile } else { $StyleProfile }
        } else {
            Get-ActiveShowTreeStyleProfile
        }

        $state = [PSCustomObject]@{
            AllItems     = New-Object System.Collections.Generic.List[object]
            InputItems   = @{} # FullPath -> TreeItem
            SeenItems    = @{} # FullPath -> bool
            StyleProfile = $resolvedStyleProfile
            LastGapMode  = 'None'
            LastSubtreeRenderedLines = $false
        }
    }

    process {
        if ($null -ne $Items) {
            foreach ($i in $Items) {
                if ($null -ne $i) {
                    $state.AllItems.Add($i)
                    if ($null -ne $i.FullPath) { $state.InputItems[$i.FullPath] = $i }
                }
            }
        }
        if ($null -ne $_) {
            if ($null -ne $_.FullPath -and -not $state.InputItems.ContainsKey($_.FullPath)) {
                $state.AllItems.Add($_)
                $state.InputItems[$_.FullPath] = $_
            }
            elseif ($null -eq $_.FullPath) { $state.AllItems.Add($_) }
        }
    }

    end {
        if ($state.AllItems.Count -eq 0) { return }

        # Identify roots in the input set (items whose parent is NOT in the input set)
        $roots = New-Object System.Collections.Generic.List[object]
        foreach ($item in $state.AllItems) {
            $isRoot = $true
            if ($null -ne $item.ParentPath -and $state.InputItems.ContainsKey($item.ParentPath)) {
                $isRoot = $false
            }
            if ($isRoot) { 
                [void]$roots.Add($item) 
            }
        }

        if ($roots.Count -eq 0) { $roots = $state.AllItems }
        else { $roots = $roots.ToArray() }

        $topLevelNoSpan = $false
        if ($Mode -eq 'Tree') {
            $hasContainer = $false
            foreach ($r in $roots) { if ($r.IsContainer) { $hasContainer = $true; break } }
            $topLevelNoSpan = -not $hasContainer
        }

        $rootsArray = @($roots)
        for ($i = 0; $i -lt $rootsArray.Count; $i++) {
            $item = $rootsArray[$i]
            if ($null -ne $item.FullPath -and $state.SeenItems.ContainsKey($item.FullPath)) { continue }

            $isLast = ($i -eq $rootsArray.Count - 1)
            
            # Gap logic before directory root if previous was file root
            if ($Gap -and ($state.LastGapMode -eq 'None' -or $state.LastGapMode -eq 'TailGapDone') -and $i -gt 0) {
                $prevRoot = $rootsArray[$i-1]
                $prevWasFile = $prevRoot.IsLeaf
                $currIsDirectory = $item.IsContainer
                
                if ($prevWasFile -and $currIsDirectory) {
                    if ($state.LastGapMode -ne 'TailGapDone') {
                        $gapConnector = Get-Connector -Type Gap -Mode $Mode -Ascii:$Ascii -StyleProfile $state.StyleProfile
                        $escG = [char]27
                        $colorGap = $Colorize ? "${escG}[90m" : ""
                        $colorReset = $Colorize ? "${escG}[0m" : ""
                        Write-Output "${colorGap}${gapConnector}${colorReset}"
                    }
                    $state.LastGapMode = 'Internal'
                }
            }

            if ($state.LastGapMode -eq 'Tail') {
                $state.LastGapMode = 'None'
                if ($Gap -and $Mode -ne 'Tree' -and $state.LastSubtreeRenderedLines) {
                    $gapConnector = Get-Connector -Type Gap -Mode $Mode -Ascii:$Ascii -StyleProfile $state.StyleProfile
                    $escG = [char]27
                    $colorGap = $Colorize ? "${escG}[90m" : ""
                    $colorReset = $Colorize ? "${escG}[0m" : ""
                    Write-Output "${colorGap}${gapConnector}${colorReset}"
                    $state.LastGapMode = 'TailGapDone'
                }
                else { $state.LastGapMode = 'TailGapDone' }
            }

            # If we didn't just render a tail gap, check for sibling gap
            if ($Gap -and $Mode -ne 'Tree' -and $state.LastGapMode -ne 'TailGapDone' -and $i -gt 0) {
                 $prevRoot = $rootsArray[$i-1]
                 
                 $prevHasChildren = $false
                 if ($prevRoot.IsContainer) {
                    foreach ($val in $state.InputItems.Values) {
                        if ($val.ParentPath -eq $prevRoot.FullPath) { $prevHasChildren = $true; break }
                    }
                 }
                 
                 $currHasChildren = $false
                 if ($item.IsContainer) {
                    foreach ($val in $state.InputItems.Values) {
                        if ($val.ParentPath -eq $item.FullPath) { $currHasChildren = $true; break }
                    }
                 }
                 
                 if ($prevHasChildren -and $currHasChildren) {
                     # Suppress sibling gap if next root will trigger internal gap
                     $prevWasFile = $prevRoot.IsLeaf
                     $currIsDirectory = $item.IsContainer
                     $nextWillTriggerInternal = $prevWasFile -and $currIsDirectory

                     if (-not $nextWillTriggerInternal) {
                        $gapConnector = Get-Connector -Type Gap -Mode $Mode -Ascii:$Ascii -StyleProfile $state.StyleProfile
                        $escG = [char]27
                        $colorGap = $Colorize ? "${escG}[90m" : ""
                        $colorReset = $Colorize ? "${escG}[0m" : ""
                        Write-Output "${colorGap}${gapConnector}${colorReset}"
                        $state.LastGapMode = 'Sibling'
                     }
                 }
            }

            # State.LastGapMode = 'None' # removed reset as we now use it
            $results = Invoke-FormatTreeInternal `
                -Item $item `
                -Mode $Mode `
                -Ascii:$Ascii `
                -Colorize:$Colorize `
                -ShowTargets:$ShowTargets `
                -Gap:$Gap `
                -State $state `
                -Prefix "" `
                -IsLast $isLast `
                -NoSpan ($item.IsLeaf -and $topLevelNoSpan)
            
            if ($null -ne $results) { foreach ($line in $results) { Write-Output $line } }
        }
    }
}

function Invoke-FormatTreeInternal {
    [CmdletBinding()]
    param($Item, $Mode, $Ascii, $Colorize, $ShowTargets, $Gap, $State, $Prefix, $IsLast, $NoSpan)

    $results = @()
    $type = $Item.IsContainer ? 'Directory' : 'File'
    $connector = Get-Connector -Type $type -Mode $Mode -Ascii:$Ascii -IsLast $IsLast -NoSpan $NoSpan -StyleProfile $State.StyleProfile

    $targetText = ""
    if ($ShowTargets -and $Item.IsLink -and $Item.Link.Target) {
        $escT = [char]27; $resetT = $Colorize ? "${escT}[0m" : ""; $dimT = $Colorize ? "${escT}[90m" : ""
        $targetText = " ${dimT}->${resetT} $($Item.Link.Target)"
    }

    $style = Get-ItemStyle -Item $Item -Colorize:$Colorize -StyleProfile $State.StyleProfile
    if ($null -ne $Item.FullPath) { $State.SeenItems[$Item.FullPath] = $true }

    $esc = [char]27; $reset = $Colorize ? "${esc}[0m" : ""; $dim = $Colorize ? "${esc}[90m" : ""
    $results += "${dim}${Prefix}${dim}${connector}$($style.Ansi)$($Item.Name)$reset$targetText"

    # Reset gap mode when starting new item
    $State.LastGapMode = 'None'
    $State.LastSubtreeRenderedLines = $false

    # Discover children strictly from the input stream
    if ($Item.IsContainer) {
        $parentPath = $Item.FullPath
        $childList = New-Object System.Collections.Generic.List[object]
        foreach ($i in $State.AllItems) {
            if ($i.ParentPath -eq $parentPath) { [void]$childList.Add($i) }
        }
        $children = $childList.ToArray()
    }
    else {
        $children = @()
    }
    
    # Fallback to .Children if they are present but were NOT in AllItems
    # This is needed for tests that don't pass the full stream
    if ($children.Count -eq 0 -and $null -ne $Item.Children -and $Item.Children.Count -gt 0) {
        $children = $Item.Children
    }
    
    if ($null -ne $children -and $children.Count -gt 0) {
        # Filter child pool to only those that should be rendered
        # If we have a full stream (AllItems), only show children that are in it.
        # This handles cases like -DirectoryOnly where files are excluded from the stream.
        if ($State.AllItems.Count -gt 1) {
             $childPoolList = New-Object System.Collections.Generic.List[object]
             foreach ($c in $children) {
                 if ($State.InputItems.ContainsKey($c.FullPath) -or $null -eq $c.FullPath) {
                     [void]$childPoolList.Add($c)
                 }
             }
             $childPool = $childPoolList.ToArray()
        }
        else {
             $childPool = @($children)
        }

        if ($childPool.Count -gt 0) {
            $prefixSymbol = Get-Connector -Type Prefix -Mode $Mode -Ascii:$Ascii -IsLast $IsLast -StyleProfile $State.StyleProfile
            $newPrefix = $Prefix + $prefixSymbol
            
            $currentLevelNoSpan = $false
            if ($Mode -eq 'Tree') {
                $hasContainer = $false
                foreach ($cp in $childPool) { if ($cp.IsContainer) { $hasContainer = $true; break } }
                $currentLevelNoSpan = -not $hasContainer
            }

            $hasRenderedChildren = $false
            for ($i = 0; $i -lt $childPool.Count; $i++) {
                $child = $childPool[$i]; $isLastChild = ($i -eq $childPool.Count - 1)
                
                # Gap logic before directory if previous was file
                if ($Gap -and ($State.LastGapMode -eq 'None' -or $State.LastGapMode -eq 'TailGapDone') -and $i -gt 0) {
                    $prev = $childPool[$i-1]
                    $prevWasFile = $prev.IsLeaf
                    $currIsDirectory = $child.IsContainer
                    
                    if ($prevWasFile -and $currIsDirectory) {
                        # Only add a gap if we didn't just add one via TailGapDone
                        if ($State.LastGapMode -ne 'TailGapDone') {
                            $gapConnector = Get-Connector -Type Gap -Mode $Mode -Ascii:$Ascii -StyleProfile $State.StyleProfile
                            $cGap = $Colorize ? "$esc[90m" : ""
                            $cReset = $Colorize ? "$esc[0m" : ""
                            $results += "${cGap}${newPrefix}${gapConnector}${cReset}"
                        }
                        $State.LastGapMode = 'Internal'
                    }
                }

                $res = Invoke-FormatTreeInternal -Item $child -Mode $Mode -Ascii:$Ascii -Colorize:$Colorize -ShowTargets:$ShowTargets -Gap:$Gap -State $State -Prefix $newPrefix -IsLast $isLastChild -NoSpan ($child.IsLeaf -and $currentLevelNoSpan)
                if ($null -ne $res) { 
                    $results += $res 
                    $hasRenderedChildren = $true
                    $State.LastSubtreeRenderedLines = $true
                }

                # Gap logic between children
                if ($Gap -and $i -lt $childPool.Count - 1) {
                    $next = $childPool[$i+1]
                    
                    # Discover children for gap logic
                    $childHasVisibleChildren = $child.IsContainer -and ($State.AllItems | Where-Object { $_.ParentPath -eq $child.FullPath })
                    $nextHasVisibleChildren = $next.IsContainer -and ($State.AllItems | Where-Object { $_.ParentPath -eq $next.FullPath })

                    # Reset tail gap done flag for next sibling
                    if ($State.LastGapMode -eq 'TailGapDone') { $State.LastGapMode = 'None' }

                    if ($State.LastGapMode -eq 'Tail') {
                        $State.LastGapMode = 'None'
                        # Print a gap connector if the previous subtree had a tail gap
                        if ($Mode -ne 'Tree' -and -not $isLastChild -and $State.LastSubtreeRenderedLines) {
                            $gapConnector = Get-Connector -Type Gap -Mode $Mode -Ascii:$Ascii -StyleProfile $State.StyleProfile
                            $cGap = $Colorize ? "$esc[90m" : ""
                            $cReset = $Colorize ? "$esc[0m" : ""
                            $results += "${cGap}${newPrefix}${gapConnector}${cReset}"
                            $State.LastGapMode = 'TailGapDone'
                        }
                        else { $State.LastGapMode = 'TailGapDone' }
                    }
                    elseif ($Mode -ne 'Tree' -and $childHasVisibleChildren -and $nextHasVisibleChildren) {
                        # Sibling gap between two branches with children
                        $prevWasFile = $child.IsLeaf
                        $currIsDirectory = $next.IsContainer
                        $nextWillTriggerInternal = $prevWasFile -and $currIsDirectory

                        if (-not $nextWillTriggerInternal) {
                            $gapConnector = Get-Connector -Type Gap -Mode $Mode -Ascii:$Ascii -StyleProfile $State.StyleProfile
                            $cGap = $Colorize ? "${esc}[90m" : ""
                            $cReset = $Colorize ? "${esc}[0m" : ""
                            $results += "${cGap}${newPrefix}${gapConnector}${cReset}"
                            $State.LastGapMode = 'Sibling'
                        }
                    }
                }
                elseif ($Gap -and $isLastChild -and $State.LastGapMode -ne 'Tail') {
                    # Mark tail gap needed after children if we are NOT the last sibling
                    if ($hasRenderedChildren -and -not $IsLast) {
                        $State.LastGapMode = 'Tail'
                    }
                }
            }
        }
    }
    return $results
}
