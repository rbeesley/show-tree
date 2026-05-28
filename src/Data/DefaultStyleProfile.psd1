# src/Data/DefaultStyleProfile.psd1

<#
.SYNOPSIS
    Defines the ANSI color style profile used by Show-Tree.

.DESCRIPTION
    This profile controls:
      • Base colors for files, directories, symlinks, junctions
      • Attribute overlays (Hidden, System, Temporary, etc.)
      • Foreground overrides for specific attribute/type combinations

    The profile is consumed by Get-ItemStyle in Show-TreeInternal.ps1.
#>
@{
    #
    # Base representation for Kind File and Directory
    #
    Base = @{
        File      = '37'
        Directory = '36'
    }

    #
    # Additional modifications for attributes
    #
    Attributes = @{
        None              = @{ Attributes = '90' }
        ReadOnly          = @{ Attributes = '3' }
        Hidden            = @{ Attributes = '2' }
        System            = @{
            OverrideForeground = @{
                File      = '31'
                Directory = '35'
            }
        }
        Directory         = @{ Attributes = '' }
        Archive           = @{ Attributes = '' }
        Device            = @{ Attributes = '' }
        Normal            = @{ Attributes = '' }
        Temporary         = @{ Attributes = '7' }
        SparseFile        = @{ Attributes = '7' }
        ReparsePoint      = @{ Attributes = '4' }
        Compressed        = @{ Attributes = '' }
        Offline           = @{ Attributes = '7' }
        NotContentIndexed = @{ Attributes = '' }
        Encrypted         = @{ Attributes = '' }
        IntegrityStream   = @{ Attributes = '' }
        NoScrubData       = @{ Attributes = '' }
    }
}
