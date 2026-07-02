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
        Directory = '94'
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

        Symlink = @{
            Foreground = @{
                File      = '96'
                Directory = '96'
            }
            AnsiStyle = '4'
        }

        BrokenLink = @{
            Foreground = @{
                File      = '91'
                Directory = '91'
            }
            AnsiStyle = '4;9'
        }

        #
        # Windows / provider-derived states
        #
        System = @{
            Foreground = @{
                File      = '31'
                Directory = '95'
            }
        }

        ReparsePoint = @{
            Foreground = @{
                File      = '96'
                Directory = '96'
            }
            AnsiStyle = '4'
        }

        Compressed = @{
            Foreground = @{
                File      = '91'
                Directory = '91'
            }
        }

        Encrypted = @{
            Foreground = @{
                File      = '92'
                Directory = '92'
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
                File      = '93'
                Directory = '93'
            }
        }

        Device = @{
            Foreground = @{
                File      = '93'
                Directory = '93'
            }
        }

        #
        # Unix states
        #
        Executable = @{
            Foreground = @{
                File      = '92'
                Directory = '94'
            }
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

    }
}
