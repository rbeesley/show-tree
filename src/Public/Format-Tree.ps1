# src/Public/Format-Tree.ps1

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
        $gap = -not $NoGap.IsPresent
        $resolvedStyleProfile = if ($null -ne $StyleProfile) {
            if ($StyleProfile -is [string]) {
                Get-ShowTreeStyleProfile -Path $StyleProfile
            } else {
                $StyleProfile
            }
        } else {
            Get-ActiveShowTreeStyleProfile
        }

        $allInputItems = [System.Collections.Generic.List[object]]::new()
    }

    process {
        foreach ($item in $Items) {
            if ($null -ne $item) {
                [void]$allInputItems.Add($item)
            }
        }
    }

    end {
        if ($allInputItems.Count -eq 0) {
            return
        }

        $reset = $Colorize ? $resolvedStyleProfile.Reset : ""
        $dim = $Colorize ? $resolvedStyleProfile.Dim : ""

        $itemCount = $allInputItems.Count

        # Calculate minimum depth to avoid leading indentation when roots are skipped
        $minDepth = 999
        foreach ($item in $allInputItems) {
            if ($item.Depth -lt $minDepth) {
                $minDepth = $item.Depth
            }
        }

        for ($i = 0; $i -lt $itemCount; $i++) {
            $item = $allInputItems[$i]
            $depth = $item.Depth

            # 1. Build Prefix (Vertical bars for ancestors)
            $prefixes = ""
            for ($d = $minDepth; $d -lt $depth; $d++) {
                $ancestorIsLast = $true
                # Check if there are any more items at this depth (d) later in the stream
                # that share the same ancestor as our current item.
                # Simplified: find the latest item at depth $d that is an ancestor of the current item
                # and see if it was the last sibling.
                for ($j = $i + 1; $j -lt $itemCount; $j++) {
                    if ($allInputItems[$j].Depth -eq $d) {
                        $ancestorIsLast = $false
                        break
                    }
                    if ($allInputItems[$j].Depth -lt $d) {
                        break
                    }
                }
                $prefixes += Get-Connector -Type Prefix -Mode $Mode -Ascii:$Ascii -IsLast $ancestorIsLast -StyleProfile $resolvedStyleProfile
            }

            # 2. Determine if this item is the last sibling
            $isLast = $true
            for ($j = $i + 1; $j -lt $itemCount; $j++) {
                if ($allInputItems[$j].Depth -lt $depth) {
                    break
                }
                if ($allInputItems[$j].Depth -eq $depth -and 
                        $allInputItems[$j].ParentPath -eq $item.ParentPath) {
                    $isLast = $false
                    break
                }
            }

            # 3. Connector
            $noSpan = $false
            if ($Mode -eq 'Tree' -and -not $item.IsContainer) {
                $hasLaterSiblingDirectory = $false

                for ($j = $i + 1; $j -lt $itemCount; $j++) {
                    if ($allInputItems[$j].Depth -lt $depth) {
                        break
                    }

                    if ($allInputItems[$j].Depth -eq $depth -and
                            $allInputItems[$j].ParentPath -eq $item.ParentPath -and
                            $allInputItems[$j].IsContainer) {
                        $hasLaterSiblingDirectory = $true
                        break
                    }
                }

                $noSpan = -not $hasLaterSiblingDirectory
            }

            $connector = Get-Connector `
                -Type ($item.IsContainer ? 'Directory' : 'File') `
                -Mode $Mode `
                -Ascii:$Ascii `
                -IsLast $isLast `
                -NoSpan:$noSpan `
                -StyleProfile $resolvedStyleProfile

            #
            # Gaps
            #
            if ($gap -and $i -gt 0) {
                $prev = $allInputItems[$i-1]
                $needsGap = $false
                
                if ($item.Depth -eq $prev.Depth) {
                    # Sibling gap: if previous had children
                    $prevHadChildren = $false
                    for ($j = $i; $j -lt $itemCount; $j++) {
                        if ($allInputItems[$j].ParentPath -eq $prev.FullPath) {
                            $prevHadChildren = $true
                            break
                        }
                    }
                    if ($prevHadChildren -or ($prev.IsLeaf -and $item.IsContainer)) {
                        $needsGap = $true
                    }
                } elseif ($item.Depth -lt $prev.Depth) {
                    # Tail gap: we moved up
                    # Look back to find if the sibling of the current item we just finished had children
                    $needsGap = $true 
                }
        
                if ($needsGap) {
                    $gapConnector = Get-Connector -Type Gap -Mode $Mode -Ascii:$Ascii -StyleProfile $resolvedStyleProfile
                    Write-Output "${dim}${prefixes}${gapConnector}${reset}"
                }
            }
        
            # 5. Render Item
            $style = Get-ItemStyle -Item $item -Colorize:$Colorize -StyleProfile $resolvedStyleProfile
            $targetText = ""
            if ($ShowTargets -and $item.IsLink -and $item.Link.Target) {
                $targetText = " ${dim}->${reset} $($item.Link.Target)"
            }
        
            Write-Output "${dim}${prefixes}${dim}${connector}${reset}$($style.Ansi)$($item.Name)$reset$targetText".TrimEnd()
        }
    }
}
