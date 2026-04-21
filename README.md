# ShowTree

A modern PowerShell-native replacement for the classic `tree.com` command.

ShowTree provides three display modes:

- **Normal mode** — graphical Unicode tree with color  
- **Tree mode** (`-Tree`) — DOS `tree.com` compatibility  
- **Listing mode** (`-List`) — compact indentation-only output  

## Install

```powershell
Install-Module ShowTree
```

### Basic Usage

```powershell
Show-Tree
Show-Tree -Tree
Show-Tree -List
Show-Tree -Recurse
```

For full documentation, screenshots, and advanced usage, visit the GitHub repository.

---

<!-- GitHub-only content below this line -->

# ShowTree

[![PowerShell Gallery](https://img.shields.io/powershellgallery/v/ShowTree.svg)](https://www.powershellgallery.com/packages/ShowTree)
[![Downloads](https://img.shields.io/powershellgallery/dt/ShowTree.svg)](https://www.powershellgallery.com/packages/ShowTree)

A modern, PowerShell-native replacement for the classic `tree.com` command — redesigned for clarity, correctness, and modern workflows.

ShowTree provides three display modes:

- **Normal mode** (default): graphical Unicode tree with color, files, and depth control  
- **Tree mode** (`-Tree`): faithful DOS `tree.com` compatibility mode  
- **Listing mode** (`-List`): compact, indentation-only output ideal for piping, grepping, and exporting  

---

## Why ShowTree?

`tree.com` hasn't changed since the 1990s — but your filesystem has.

ShowTree adds:

- Unicode connectors for clean, readable output  
- Color support with attribute-aware styling  
- Depth control and recursion shortcuts  
- Hidden/system filtering that matches `tree.com`  
- Reparse point detection and optional target display  
- Gap logic for visually separating blocks  
- A compact listing mode for automation  
- Accurate path casing normalization  
- Full support for NTFS, ReFS, FAT, and network paths  

All implemented in pure PowerShell with no external dependencies.

---

## Features

- Graphical Unicode tree with color syntax and clean connectors  
- ASCII fallback for legacy environments  
- Full `tree.com` compatibility mode  
- Compact listing mode for scripts and automation  
- Depth control (`-MaxDepth`, `-Depth`, `-Recurse`)  
- File inclusion/exclusion (`-Files`, `-NoFiles`)  
- Gap control for readability (`-NoGap`)  
- Hidden/system file filtering  
- Reparse point target display (`-ShowTargets`)  
- Accurate path casing normalization  
- Works on NTFS, ReFS, FAT, and UNC paths  

---

## Screenshots

### Normal Mode

![Normal mode](docs/normal-mode.png)

### Tree Mode

![Tree mode](docs/tree-mode.png)

### Listing Mode

![Listing mode](docs/listing-mode.png)

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
Show-Tree -Tree
```

### Compact listing mode

```powershell
Show-Tree -List
```

### ASCII connectors

```powershell
Show-Tree -Ascii
```

---

## Parameter Summary

| Parameter | Description |
| --------- | ----------- |
| `-Tree` | Enables DOS compatibility mode (`-MaxDepth -1`, `-Mono`, `-NoFiles` by default). |
| `-List` / `-Listing` | Compact indentation-only mode. |
| `-MaxDepth` / `-Depth` | Maximum recursion depth (`-1` = unlimited). |
| `-Recurse` | Shortcut for unlimited depth. |
| `-Mono` | Disable color. |
| `-Color` | Enable color in Tree mode. |
| `-Files` | Show files in Tree mode. |
| `-NoFiles` | Hide files. |
| `-HideHidden` / `-ShowHidden` | Control visibility of hidden items. |
| `-HideSystem` / `-ShowSystem` | Control visibility of system items. |
| `-ShowTargets` / `-NoTargets` | Show or hide reparse point targets. |
| `-NoGap` | Disable gap lines. |
| `-Ascii` | Use ASCII connectors instead of Unicode. |
| `-DebugAttributes` | Show attribute debug info. |

---

## Examples

Display the current directory:

```powershell
Show-Tree
```

Tree.com-style output:

```powershell
Show-Tree -Tree
```

List everything under C:\ with unlimited depth:

```powershell
Show-Tree C:\ -Recurse
```

Compact listing for scripting:

```powershell
Show-Tree -List | Select-String src
```

Export to a file:

```powershell
Show-Tree C:\ -List | Out-File listing.txt
```

---

## License

This project is licensed under the MIT License. See the LICENSE file for details.

---

## Author

**Ryan Beesley**  
Version 1.1.0  
April 2026

A modern, extensible reimplementation of the classic `tree.com` utility — with graphical output, automation-friendly modes, and a fully PowerShell-native design.
