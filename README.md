# ShowTree

[![PowerShell Gallery](https://img.shields.io/powershellgallery/v/ShowTree.svg)](https://www.powershellgallery.com/packages/ShowTree)
[![Downloads](https://img.shields.io/powershellgallery/dt/ShowTree.svg)](https://www.powershellgallery.com/packages/ShowTree)

A modern, PowerShell-native replacement for the classic `tree.com` command — redesigned for clarity, correctness, and modern workflows.

Show-Tree supports three distinct display modes:

- **Normal**: (Default) A clean, modern Unicode tree view with gap lines and rich styling.
- **Tree**: A legacy-compatible layout mimicking the classic `tree.com` utility, now enhanced with modern defaults like color and file support.
- **List**: A flat listing of items that retains hierarchical context.

---

## Why ShowTree?

`tree.com` hasn't changed since the 1990s — but your filesystem has.

ShowTree adds:

- **Cross-Platform Support**: Works on Windows (Desktop/Core) and Linux.
- **Localization**: Native support for multiple cultures (English, French, and Pseudo-Loc currently).
- **Style Profiles**: Extensible ANSI-based styling for file types and states (Hidden, Symlink, Executable, etc.).
- **Unicode Connectors**: Clean, readable output with ASCII fallback.
- **Color support**: Attribute-aware styling with a built-in legend.
- **Depth control**: Granular recursion control (`-MaxDepth`, `-Recurse`).
- **Filtering**: Glob-based include/exclude rules with exact-match precedence.
- **Reparse point detection**: Detects and displays targets for Junctions and Symlinks.
- **Gap logic**: Intelligently separates blocks for visual clarity.

All implemented in PowerShell with no external dependencies other than the .NET Framework for tree.com compatibility.

---

## Features

- Graphical Unicode tree with color syntax and clean connectors
- ASCII fallback for legacy environments
- Full `tree.com` compatibility mode (Windows only)
- Compact listing mode for scripts and automation
- Style Profiles via `Set-ShowTreeStyleProfile`
- Cultural localization support (`-Culture`)
- Reparse point target display (`-ShowTargets`)
- Works on NTFS, ReFS, FAT, ext4, and UNC paths

---

## Platform Support

PowerShell 5.1+ on Windows and PowerShell 7+ on Linux/macOS: Normal and Listing modes are expected to work, but cross-platform support is still being validated. Tree mode emulates low-level Windows `tree.com` behavior and is likely to only be supported on Windows.

| Platform                         | Normal mode | Listing mode | Tree mode     |
|----------------------------------|-------------|--------------|---------------|
| Windows PowerShell 5.1 (Desktop) | Supported   | Supported    | Supported     |
| PowerShell 7+ on Windows (Core)  | Supported   | Supported    | Supported     |
| PowerShell 7+ on Linux (Core)    | Supported   | Supported    | Not supported |
| PowerShell 7+ on macOS (Core)    | Supported   | Supported    | Not supported |

---

## Screenshots

### High level view of modes

![Comparison of modes](docs/modes.png)

### Normal Mode

![Normal mode](docs/normal-mode.png)  
Normal mode is the standard way to use `Show-Tree`. It provides granular control and makes it a modern interpretation for `tree.com` for PowerShell.

### Legacy `tree.com` is broken

![Legacy tree.com](docs/tree.com.png)  
`tree.com` will follow all Junctions and Symlinks, and doesn't limit depth. This can get stuck in an unlimited recursion.

### Tree Mode (legacy backwards compatibility)

![Legacy tree mode](docs/tree-mode.png)  
Tree mode follows the output and error messages of `tree.com` very closely. It also defaults to handle files the same way, but it can be customized.

### Tree Mode (modern)

![Modern tree mode](docs/tree-mode-modern.png)  
`Show-Tree . -Files` is the equivalient to `tree.com . /F`, but `-ShowHidden`, `-ShowSystem`, `-Color`, and other options give you a mode which retains the look and feel of a modern `tree.com`. By showing link targets and not following them, `Show-Tree` resolves one of the biggest problems with `tree.com` on modern systems.

### Listing Mode

![Listing mode](docs/listing-mode.png)  
Listing mode gives you a tight listing of the files and directories on a system. It benefits the most from having color enabeled to see folders and files at a glance, and minimally shows the tree structure, making it an ideal mode for downstream processing.

---

## Usage

### Basic usage

```powershell
Show-Tree
```

### Show only directories

```powershell
Show-Tree -NoFiles
```

### Unlimited depth

```powershell
Show-Tree -Recurse
```

### DOS `tree.com` compatible mode

```powershell
Show-Tree -Mode Tree
```

### Compact listing mode

```powershell
Show-Tree -Mode List
```

### ASCII connectors

```powershell
Show-Tree -Ascii
```

### Style and Legend

```powershell
# Show the color legend for the current platform
Show-Tree -Legend

# Show the legend for all supported states (Windows + Unix)
Show-Tree -LegendAll

# Override culture for localized strings
Show-Tree -Culture fr-FR
```

---

## Filtering (Include / Exclude)

ShowTree supports PowerShell-style glob filtering with well-defined precedence rules.
Exact Include always wins.
Exact Exclude always wins (even over glob Include).
Glob Include resurrects items removed by Hidden/System/Exclude (glob).
Hidden/System remove items unless resurrected.
Glob Exclude removes items unless resurrected.

### Exclude

```powershell
Show-Tree -Exclude pattern1, pattern2, ...
```

Removes matching items. Exact matches take precedence over Include globs.

### Include

```powershell
Show-Tree -Include pattern1, pattern2, ...
```

Selectively resurrects items removed by Hidden, System, or Exclude (glob).

### Precedence Rules

1. Exact Include always wins
2. Exact Exclude always wins (even over glob Include)
3. Glob Include resurrects items removed by Hidden/System/Exclude (glob)
4. Hidden/System remove items unless resurrected
5. Glob Exclude removes items unless resurrected
6. Items unaffected by any rule are kept

### Hide everything starting with a dot except `.vscode`

```powershell
Show-Tree -Exclude '.*' -Include '.vscode'
```

### Exclude `.git` exactly, but include `.gitignore`, `.github`, etc.

```powershell
Show-Tree -Exclude '.git' -Include '.git*'
```

### Hide hidden/system items but bring back `.config`

```powershell
Show-Tree -HideHidden -HideSystem -Include '.config'
```

---

## Parameter Summary

| Parameter                                   | Description                                                                                        |
|---------------------------------------------|----------------------------------------------------------------------------------------------------|
| `‑Mode` <`Normal`\|`Tree`\|`List`>          | Selects the output mode. Defaults to `Normal`.                                                     |
| `‑MaxDepth` / `‑Depth`                      | Maximum recursion depth (`‑1` = unlimited). Defaults to `6`.                                       |
| `‑Recurse`                                  | Shortcut for unlimited depth.                                                                      |
| `‑Color` / `‑NoColor`                       | Force color on or off. Defaults to ON for modern modes and modern Tree mode. (Alias: `‑Mono`)      |
| `‑Files` / `‑NoFiles`                       | Control if files are shown. Defaults to ON for all modern modes.                                   |
| `‑Targets` / `‑NoTargets`                   | Show or hide reparse point targets. ON by default for `Normal` and `Tree` modes.                   |
| `‑Hidden` / `‑NoHidden`                     | Control visibility of hidden items. OFF by default.                                                |
| `‑System` / `‑NoSystem`                     | Control visibility of system items. OFF by default.                                                |
| `‑Exclude` *pattern* / `‑Include` *pattern* | Glob patterns that explicitly exclude or include items. Exact matches override all other filters.  |
| `-Gap` / `‑NoGap`                           | Control gap lines. Defaults to `Show` for `Normal` and modern `Tree` modes, and `None` for `List`. |
| `‑Compat`                                   | Enables strict legacy emulation for `‑Mode Tree` (Monochrome, folders-only, `tree.com` sorting).   |
| `‑Ascii`                                    | Use ASCII connectors instead of Unicode.                                                           |
| `‑Legend` / `-LegendAll`                    | Show the style legend.                                                                             |
| `‑Platform`                                 | Preview another platform's states in legend (Windows/Unix).                                        |
| `-Culture`                                  | Override culture for localized strings.                                                            |

### Compatibility Mode

While `-Mode Tree` provides a modern take on the classic layout, you can use the `-Compat` switch to enable strict legacy emulation. This is useful for scripts or logs that require the exact output format of the original Windows utility:

```powershell
# Modern Tree view (Color, Files, and Targets enabled by default)
Show-Tree -Mode Tree

# Strict Legacy Emulation (Monochrome, Folders-only, Win32 sorting)
Show-Tree -Mode Tree -Compat
```

Note: The -Compat switch is only valid when using -Mode Tree.

---

## Documentation

For detailed information on usage, parameters, and examples, see the [Wiki](https://github.com/rbeesley/show-tree/wiki) or use `Get-Help Show-Tree -Full`.

### Technical Architecture

If you are interested in the internal design or wish to contribute to the project, please refer to our technical guides:

- [Core Architecture](docs/ARCHITECTURE.md): Redesign of the traversal and rendering engines.
- [Build System](docs/BUILD-ARCHITECTURE.md): Task-driven workflow and cross-version transpilation.
- [Test System](docs/TEST-ARCHITECTURE.md): Hash-based module caching and in-memory fixture trees.

---

## Installation

### From [PowerShell Gallery](https://www.powershellgallery.com/packages/ShowTree) (recommended)

```powershell
Install-Module ShowTree
```

PowerShell will auto-load the module when you run:

```powershell
Show-Tree
```

### From GitHub

Clone the repository and place the `ShowTree` folder into one of your module paths:

- Current user:  
  `~/Documents/PowerShell/Modules/`

- All users:  
  `C:\Program Files\PowerShell\7\Modules\`

---

## Examples

Display the current directory:

```powershell
Show-Tree
```

Tree.com-style output:

```powershell
Show-Tree -Mode Tree
```

List everything under C:\ with unlimited depth:

```powershell
Show-Tree C:\ -Recurse
```

Compact listing for scripting:

```powershell
Show-Tree -Mode List | Select-String src
```

Export to a file:

```powershell
Show-Tree C:\ -Mode List | Out-File listing.txt
```

---

### Testing

Install Pester 5.7.1 or better:

```powershell
Install-Module -Name Pester -Force -MinimumVersion 5.7.1
```

From the repo root, run:

```powershell
.\Run-Tests.ps1
```

You may also run an individual test file with this command:

```powershell
.\Run-TestFile.ps1 -Path <.[\Private|\Public]*.Tests.ps1>
```

From Visual Studio Code, and any time you've made changes you want to test, manually import the test module first by running the following in the PowerShell terminal window in Code:

```powershell
. .\Tests\Helpers\Import-ShowTreeUnderTest.ps1
```

This can also be done by making this file the focus in your editor and pressing the run button to the far right of the tabs. This has the added benefit of saving all modified files so that you are commiting them to the test state.

Then you may use the Code Lens `Run Tests` / `Debug Tests` / `Run Test` / `Debug Test` buttons to have more grainular control over what you are testing.

The Pester Test Explorer extension is not recommended for use as it handles the environment in a way which often conflicts.

---

## Style Profiles

ShowTree v2.0 introduces a modular style profile system. You can customize colors for base types and specific item states.

### Example: Setting a custom profile

```powershell
$myStyle = @{
    States = @{
        Executable = @{ Foreground = @{ File = '32' }; AnsiStyle = '1' }
    }
}
Set-ShowTreeStyleProfile -InputObject $myStyle
```

### State Styling Logic

ShowTree style profiles can define visual overlays for item states:

```powershell
States = @{
    Hidden = @{ AnsiStyle = '2' }
    System = @{
        Foreground = @{
            File      = '31'
            Directory = '35'
        }
    }
    Executable = @{
        Foreground = @{
            File      = '32'
            Directory = '36'
        }
        AnsiStyle = '1'
    }
}
```

`AnsiStyle` contains ANSI SGR parameters without the escape sequence wrapper. Multiple parameters may be separated with semicolons:

```powershell
States = @{
    Hidden = @{ AnsiStyle = '2' }      # Dim
    Symlink = @{ AnsiStyle = '4' }     # Underline
    BrokenLink = @{ AnsiStyle = '9' }  # Strikethrough
}
```

### Common states

| State               | Platform      | Meaning                                                                 |
|---------------------|---------------|-------------------------------------------------------------------------|
| `Hidden`            | Windows, Unix | Hidden file or directory. On Unix, names beginning with `.` are hidden. |
| `ReadOnly`          | Windows, Unix | Read-only item.                                                         |
| `System`            | Windows       | Windows system file or directory.                                       |
| `Temporary`         | Windows       | Temporary file.                                                         |
| `SparseFile`        | Windows       | Sparse file.                                                            |
| `ReparsePoint`      | Windows       | Reparse point, including symlinks and junctions.                        |
| `Compressed`        | Windows       | Compressed file or directory.                                           |
| `Offline`           | Windows       | Offline file.                                                           |
| `NotContentIndexed` | Windows       | Excluded from content indexing.                                         |
| `Encrypted`         | Windows       | Encrypted file or directory.                                            |
| `IntegrityStream`   | Windows       | Integrity stream attribute.                                             |
| `NoScrubData`       | Windows       | Data integrity scrubbing disabled.                                      |
| `Symlink`           | Windows, Unix | Symbolic link.                                                          |
| `BrokenLink`        | Windows, Unix | Symbolic link whose target cannot be resolved.                          |
| `Executable`        | Unix          | File with at least one execute permission bit.                          |
| `SetUid`            | Unix          | Set-user-ID permission bit.                                             |
| `SetGid`            | Unix          | Set-group-ID permission bit.                                            |
| `Sticky`            | Unix          | Sticky permission bit.                                                  |

### Additional native Windows attributes

ShowTree can also derive states from native Windows file attributes. These are supported for custom style profiles, but they are not styled by the default profile because they are usually too common or not visually useful.

| State     | Notes                                                                                                |
|-----------|------------------------------------------------------------------------------------------------------|
| `Archive` | Common on ordinary Windows files. Styling it usually affects almost everything.                      |
| `Normal`  | Means no other file attributes are set. Usually better represented by the base file/directory style. |
| `Device`  | Reserved by Windows. Rarely useful for styling.                                                      |

Example:

```powershell
States = @{
  Archive = @{ AnsiStyle = '2' }
  Normal  = @{ AnsiStyle = '90' }
}
```

### Base Styles vs States

Use `Base` for what an item is:

```powershell
Base = @{
  File      = '37'  # White
  Directory = '36'  # Cyan
}
```

Use `States` for traits. If a state defines a `Foreground` for a specific kind, it overrides the `Base` color:

```powershell
States = @{
# Directories marked 'System' will be Magenta (35) instead of Cyan (36)
  System = @{
    Foreground = @{
      File      = '31'
      Directory = '35'
    }
  }
}
```

`Directory` and `File` are kinds, not states, so they belong under `Base`, not `States`.

---

## Contributing

Contributions are welcome! If you're looking to help improve ShowTree, please check out the [Architecture Guide](docs/ARCHITECTURE.md) for an overview of how the project is structured.

### Reporting Issues

Please use the [GitHub Issue Tracker](https://github.com/rbeesley/show-tree/issues) to report bugs or request features.

---

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

---

## Author

**Ryan Beesley**  
Version 2.0.0  
July 2026

A modern, extensible reimplementation of the classic `tree.com` utility — with graphical output, automation-friendly modes, and a fully PowerShell-native design.
