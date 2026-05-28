# src/Data/BaseStyleProfile.psd1

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
            Header              = 'Legend'
            HeaderUnderline     = '------'
            Types               = 'Types:'
            Attributes          = '  Attributes:'
        }
        TreeMode = @{
            InvalidDrive        = 'Invalid drive specification'
            VolumeListing       = 'Folder PATH listing for volume {0}'
            VolumeSerial        = 'Volume serial number is {0}'
            InvalidPath         = 'Invalid path - {0}'
            NoSubfolders        = 'No subfolders exist'
        }
        Errors = @{
            WindowsOnly         = 'ShowTree currently supports Windows only for Tree mode.'
            ColorMonoConflict   = 'Cannot specify both -Color and -Mono.'
            FilesConflict       = 'Cannot specify both -Files (or -ShowFiles) and -NoFiles.'
            HiddenConflict      = 'Cannot specify both -ShowHidden and -HideHidden.'
            SystemConflict      = 'Cannot specify both -ShowSystem and -HideSystem.'
            TargetsConflict     = 'Cannot specify both -ShowTargets and -NoTargets.'
            GapConflict         = 'Cannot specify both -Gap and -NoGap.'
            InvalidAttribute    = "Style profile attribute '{0}' is not a valid System.IO.FileAttributes value."
        }
    }
}
