# src/Private/Rendering/Get-Connector.ps1

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
        [bool]$NoSpan = $false,

        [Parameter(Mandatory)]
        [object]$StyleProfile
    )

    $encoding = $Ascii ? 'Ascii' : 'Unicode'
    $connectorSet = $StyleProfile.Connectors[$Mode][$encoding]

    if ($null -eq $connectorSet) {
        # Fallback to Normal if mode not found
        $connectorSet = $StyleProfile.Connectors['Normal'][$encoding]
    }

    if ($Mode -eq 'Tree' -and $Type -eq 'File' -and $NoSpan) {
        return $connectorSet.NoSpan
    }

    switch ($Type) {
        'File' {
            return $IsLast ? $connectorSet.FileLast : $connectorSet.File
        }
        'Directory' {
            return $IsLast ? $connectorSet.DirectoryLast : $connectorSet.Directory
        }
        'Prefix' {
            return $IsLast ? $connectorSet.PrefixLast : $connectorSet.Prefix
        }
        'Gap' {
            return $connectorSet.Gap
        }
    }
}
