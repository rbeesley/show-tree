# src\Private\Rendering\Write-Gap.ps1

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
