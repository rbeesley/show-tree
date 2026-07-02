# src/Data/BaseStyleProfile.psd1

<#
.SYNOPSIS
    Defines the structural symbols and UI strings used by Show-Tree.

.DESCRIPTION
    This profile contains the core definitions for tree connectors (Unicode and ASCII), 
    ANSI escape sequences, and localized UI string keys. It serves as the foundation 
    that other profiles extend.
#>
@{
    #
    # Connectors and Gaps
    #
    # Symbols are mapped by Mode and Encoding (Unicode/Ascii)
    #
    Connectors = @{
        Normal = @{
            Unicode = @{
                File          = '╟── '
                FileLast      = '╙── '
                Directory     = '╠══ '
                DirectoryLast = '╚══ '
                Prefix        = '║   '
                PrefixLast    = '    '
                Gap           = '║'
                NoSpan        = '    '
            }
            Ascii = @{
                File          = '+-- '
                FileLast      = '\-- '
                Directory     = '+== '
                DirectoryLast = '\== '
                Prefix        = '|   '
                PrefixLast    = '    '
                Gap           = '|'
                NoSpan        = '    '
            }
        }
        Tree = @{
            Unicode = @{
                File          = '│   '
                FileLast      = '│   '
                Directory     = '├───'
                DirectoryLast = '└───'
                Prefix        = '│   '
                PrefixLast    = '    '
                Gap           = '│'
                NoSpan        = '    '
            }
            Ascii = @{
                File          = '|   '
                FileLast      = '|   '
                Directory     = '+---'
                DirectoryLast = '\---'
                Prefix        = '|   '
                PrefixLast    = '    '
                Gap           = '|'
                NoSpan        = '    '
            }
        }
        List = @{
            Unicode = @{
                File          = ' '
                FileLast      = ' '
                Directory     = ' '
                DirectoryLast = ' '
                Prefix        = ' '
                PrefixLast    = ' '
                Gap           = ' '
                NoSpan        = ' '
            }
            Ascii = @{
                File          = ' '
                FileLast      = ' '
                Directory     = ' '
                DirectoryLast = ' '
                Prefix        = ' '
                PrefixLast    = ' '
                Gap           = ' '
                NoSpan        = ' '
            }
        }
    }

    # Base escape character
    Esc = [char]27

    # Standard sequences
    Reset = "$([char]27)[0m"
    Dim   = "$([char]27)[90m"

    #
    # UI Strings
    #
    UIStrings = @{
        Legend = @{
            Header                  = 'Legend'
            HeaderUnderline         = '------'
            Types                   = 'Types:'
            States                  = '  States:'
            File                    = 'File'
            Directory               = 'Directory'
        }
        TreeMode = @{
            InvalidDrive            = 'Invalid drive specification'
            VolumeListing           = 'Folder PATH listing for volume {0}'
            VolumeSerial            = 'Volume serial number is {0}'
            InvalidPath             = 'Invalid path - {0}'
            NoSubfolders            = 'No subfolders exist'
        }
        Errors = @{
            WindowsOnly             = "Mode 'Tree' is only supported on Windows."
            ColorMonoConflict       = 'Cannot specify both -Color and -Mono.'
            FilesConflict           = 'Cannot specify both -Files (or -ShowFiles) and -NoFiles.'
            HiddenConflict          = 'Cannot specify both -ShowHidden and -HideHidden.'
            SystemConflict          = 'Cannot specify both -ShowSystem and -HideSystem.'
            TargetsConflict         = 'Cannot specify both -ShowTargets and -NoTargets.'
            GapConflict             = 'Cannot specify both -Gap and -NoGap.'
            CompatRequiresTree      = "The -Compat switch can only be used with -Mode Tree."
            PlatformRequiresLegend  = 'The -Platform parameter is only valid with -Legend or -LegendAll.'
            InvalidFormatInput      = "Format-Tree expects ShowTree.TreeRecord input."
            MissingMetadata         = "Tree record '{0}' is missing ShowTree.TreeLayout metadata."
            MissingGapMetadata      = "Gap record is missing ShowTree.TreeLayout metadata."
            Win32WindowsOnly        = "Win32 tree child provider is only supported on Windows."
            MissingGetChildren      = "Tree child provider '{0}' does not define a GetChildren scriptblock."
            MissingTreeItem         = "Tree record type 'Item' requires a TreeItem."
            MissingTreeLayout       = "Tree record requires a ShowTree.TreeLayout layout object."
            PathNotFound            = "Cannot find path '{0}' because it does not exist."
        }
    }

    StylePriority = @(
    # No-op / structural
        'Normal'
        'Directory'
        'Archive'

    # Low-signal metadata
        'NotContentIndexed'
        'Temporary'
        'SparseFile'
        'ReadOnly'
        'Hidden'

    # Storage / availability / integrity
        'Compressed'
        'Encrypted'
        'IntegrityStream'
        'NoScrubData'
        'Offline'

    # Special filesystem object kinds
        'Device'
        'BlockDevice'
        'CharacterDevice'
        'Pipe'
        'Socket'

    # Link / reparse semantics
        'ReparsePoint'
        'Junction'
        'Symlink'

    # Permission / executable semantics
        'Executable'
        'OtherWritable'
        'Sticky'
        'SetGid'
        'SetUid'
        'StickyOtherWritable'

    # Protected/system semantics
        'System'

    # Error states
        'BrokenLink'
    )
}
