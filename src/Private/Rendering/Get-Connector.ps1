# src\Private\Rendering\Get-Connector.ps1

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
            'File'      {
                return             ( $Ascii ? '|   ' : '│   ' )
            }
            'Directory' {
                return ( $IsLast ? ( $Ascii ? '\---' : '└───' ) `
                                 : ( $Ascii ? '+---' : '├───' ))
            }
            'Gap'       {
                return             ( $Ascii ? '|'    : '│' )
            }
            'Prefix'    {
                return ( $IsLast ? '    ' `
                                 : ( $Ascii ? '|   ' : '│   ' ))
            }
        }
    }

    #
    # Graphical Unicode mode (Show-Tree default)
    #
    switch ($Type) {
        'File' {
            return ( $IsLast ? ( $Ascii ? '\-- ' : '╙── ' ) `
                             : ( $Ascii ? '+-- ' : '╟── ' ))
        }

        'Directory' {
            return ( $IsLast ? ( $Ascii ? '\== ' : '╚══ ' ) `
                             : ( $Ascii ? '+== ' : '╠══ ' ))
        }

        'Gap' {
            return             ( $Ascii ? '|' : '║' )
        }

        'Prefix' {
            return ( $IsLast ? ( '    ' ) `
                             : ( $Ascii ? '|   ' : '║   ' ))
        }
    }
}
