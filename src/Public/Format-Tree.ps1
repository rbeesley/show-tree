# src/Public/Format-Tree.ps1

<#
.SYNOPSIS
    Formats tree records into a visual tree representation.

.DESCRIPTION
    The Format-Tree cmdlet takes ShowTree.TreeRecord objects (typically from Invoke-TreeTraversal)
    and renders them into string representations based on the specified mode and style.

.PARAMETER InputObject
    The tree records to format. Usually piped from Get-TreeItem.

.PARAMETER Mode
    The formatting mode ('Normal', 'Tree', 'List').

.PARAMETER Ascii
    Uses ASCII characters for tree connectors.

.PARAMETER Colorize
    Enables ANSI color coding in the output.

.PARAMETER ShowTargets
    Displays symlink and junction targets.

.PARAMETER NoGap
    Suppresses gap lines between items.

.PARAMETER StyleProfile
    A custom style profile or path to a style profile to use for formatting.

.EXAMPLE
    Get-TreeItem -Path . | Format-Tree -Mode Normal -Colorize
    Retrieves tree items for the current directory and formats them in Normal mode with color.

.LINK
    Show-Tree
    Get-TreeItem
#>
function Format-Tree {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline, Mandatory)]
        [object[]] $InputObject,

        [ValidateSet('Normal', 'Tree', 'List')]
        [string] $Mode = 'Normal',

        [switch] $Ascii,
        [switch] $Colorize,
        [switch] $ShowTargets,
        [switch] $NoGap,
        [object] $StyleProfile
    )

    begin {
        $gap = -not $NoGap.IsPresent

        $resolvedStyleProfile = if ($null -ne $StyleProfile) {
            if ($StyleProfile -is [string]) {
                Get-ShowTreeStyleProfile -Path $StyleProfile
            }
            else {
                $StyleProfile
            }
        }
        else {
            Get-ActiveShowTreeStyleProfile
        }

        $reset = $Colorize ? $resolvedStyleProfile.Reset : ''
        $dim   = $Colorize ? $resolvedStyleProfile.Dim   : ''
    }

    process {
        foreach ($record in $InputObject) {
            if ($null -eq $record) {
                continue
            }

            if ($record.PSTypeNames -notcontains 'ShowTree.TreeRecord') {
                throw "Format-Tree expects ShowTree.TreeRecord input."
            }

            switch ($record.RecordType) {
                'Item' {
                    $item = $record.TreeItem
                    $layout = $record.TreeLayout

                    if ($null -eq $item) {
                        continue
                    }

                    if ($null -eq $layout -or $layout.PSTypeNames -notcontains 'ShowTree.TreeLayout') {
                        throw "Tree record '$($item.Name)' is missing ShowTree.TreeLayout metadata."
                    }

                    $prefixes = ''
                    foreach ($ancestorIsLast in @($layout.AncestorIsLastSibling)) {
                        $prefixes += Get-Connector `
                            -Type Prefix `
                            -Mode $Mode `
                            -Ascii:$Ascii `
                            -IsLast:$ancestorIsLast `
                            -StyleProfile $resolvedStyleProfile
                    }

                    $noSpan = $false
                    if ($Mode -eq 'Tree' -and -not $item.IsContainer) {
                        $noSpan = -not $layout.HasLaterSiblingDirectory
                    }

                    $connector = Get-Connector `
                        -Type ($item.IsContainer ? 'Directory' : 'File') `
                        -Mode $Mode `
                        -Ascii:$Ascii `
                        -IsLast:$layout.IsLastSibling `
                        -NoSpan:$noSpan `
                        -StyleProfile $resolvedStyleProfile

                    $style = Get-ItemStyle `
                        -Item $item `
                        -Colorize:$Colorize `
                        -StyleProfile $resolvedStyleProfile

                    $targetText = ''
                    if ($ShowTargets -and $item.IsLink -and $item.Link.Target) {
                        $targetText = " ${dim}->${reset} $($item.Link.Target)"
                    }

                    Write-Output "${dim}${prefixes}${dim}${connector}${reset}$($style.Ansi)$($item.Name)$reset$targetText".TrimEnd()
                }

                'Gap' {
                    if (-not $gap) {
                        continue
                    }

                    $layout = $record.TreeLayout

                    if ($null -eq $layout -or $layout.PSTypeNames -notcontains 'ShowTree.TreeLayout') {
                        throw "Gap record is missing ShowTree.TreeLayout metadata."
                    }

                    $prefixes = ''
                    foreach ($ancestorIsLast in @($layout.AncestorIsLastSibling)) {
                        $prefixes += Get-Connector `
                            -Type Prefix `
                            -Mode $Mode `
                            -Ascii:$Ascii `
                            -IsLast:$ancestorIsLast `
                            -StyleProfile $resolvedStyleProfile
                    }

                    $gapConnector = Get-Connector `
                        -Type Gap `
                        -Mode $Mode `
                        -Ascii:$Ascii `
                        -StyleProfile $resolvedStyleProfile

                    Write-Output "${dim}${prefixes}${gapConnector}${reset}".TrimEnd()
                }

                default {
                    throw "Unsupported tree record type '$($record.RecordType)'."
                }
            }
        }
    }
}
