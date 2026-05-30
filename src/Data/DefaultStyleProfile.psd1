# src/Data/DefaultStyleProfile.psd1

<#
.SYNOPSIS
    Defines the ANSI color style profile used by Show-Tree.

.DESCRIPTION
    This profile uses high-signal colors inspired by common Linux
    `ls --color` directory listings, with Windows file attributes mapped
    to similar visual meanings where appropriate.

    The profile is consumed by Get-ItemStyle.
#>
@{
#
# Base representation for Kind File and Directory.
#
# Files use the terminal's default foreground. Directories use the
# familiar bold blue commonly seen in Linux directory listings.
#
    Base = @{
        File      = '39'
        Directory = '1;34'
    }

    #
    # Default state styles.
    #
    States = @{
    #
    # Universal / cross-platform states
    #
        Hidden = @{
            AnsiStyle = '2'
        }

        ReadOnly = @{
            AnsiStyle = '3'
        }

        Executable = @{
            Foreground = @{
                File      = '1;32'
                Directory = '1;34'
            }
        }

        Symlink = @{
            Foreground = @{
                File      = '1;36'
                Directory = '1;36'
            }
            AnsiStyle = '4'
        }

        BrokenLink = @{
            Foreground = @{
                File      = '1;31'
                Directory = '1;31'
            }
            AnsiStyle = '4;9'
        }

        SetUid = @{
            Foreground = '37'
            Background = '41'
        }

        SetGid = @{
            Foreground = '30'
            Background = '43'
        }

        Sticky = @{
            Foreground = '37'
            Background = '44'
        }

        OtherWritable = @{
            Foreground = @{
                File      = '34'
                Directory = '34'
            }
            Background = '42'
        }

        StickyOtherWritable = @{
            Foreground = @{
                File      = '30'
                Directory = '30'
            }
            Background = '42'
        }

        #
        # Windows / provider-derived states
        #
        System = @{
            Foreground = @{
                File      = '35'
                Directory = '35'
            }
            AnsiStyle = '2;3'
        }

        ReparsePoint = @{
            Foreground = @{
                File      = '1;36'
                Directory = '1;36'
            }
            AnsiStyle = '4'
        }

        Compressed = @{
            Foreground = @{
                File      = '1;31'
                Directory = '1;31'
            }
        }

        Encrypted = @{
            Foreground = @{
                File      = '1;32'
                Directory = '1;32'
            }
        }

        Offline = @{
            AnsiStyle = '2;7'
        }

        Temporary = @{
            AnsiStyle = '2'
        }

        SparseFile = @{
            AnsiStyle = '2'
        }

        NotContentIndexed = @{
            AnsiStyle = '2'
        }

        IntegrityStream = @{
            Foreground = @{
                File      = '36'
                Directory = '36'
            }
        }

        NoScrubData = @{
            Foreground = @{
                File      = '1;33'
                Directory = '1;33'
            }
        }

        Device = @{
            Foreground = @{
                File      = '1;33'
                Directory = '1;33'
            }
        }
    }
}
