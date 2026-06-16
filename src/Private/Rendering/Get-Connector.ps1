# src/Private/Rendering/Get-Connector.ps1

<#
.SYNOPSIS
    Returns the connector string for a given item type.

.DESCRIPTION
    The Get-Connector cmdlet retrieves the appropriate tree connector (e.g., │, ├, └) based on the 
    specified mode, item type, sibling position, and style profile. It supports both Unicode and ASCII sets.
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
