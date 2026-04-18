# ShowTree

[![PowerShell Gallery](https://img.shields.io/powershellgallery/v/ShowTree.svg)](https://www.powershellgallery.com/packages/ShowTree)
[![Downloads](https://img.shields.io/powershellgallery/dt/ShowTree.svg)](https://www.powershellgallery.com/packages/ShowTree)

A modern, PowerShell-native replacement for the classic `tree.com` command.

`ShowTree` provides three display modes:

- **Normal mode** (default): graphical Unicode tree with color, files, and depth control  
- **Tree mode** (`-Tree`): faithful DOS `tree.com` compatibility mode  
- **Listing mode** (`-Listing`): compact, indentation-only output ideal for piping, grepping, and exporting  

This module is designed to be fast, readable, and flexible, while still honoring the behavior of the original DOS tool when requested.

---

## Features

- Graphical Unicode tree with color and clean connectors  
- ASCII fallback for legacy environments  
- Full `tree.com` compatibility mode  
- Compact listing mode for scripts and automation  
- Depth control (`-MaxDepth`, `-Depth`, `-Recurse`)  
- File inclusion/exclusion (`-Files`, `-NoFiles`)  
- Gap control for readability (`-NoGap`)  
- Accurate path casing normalization  
- Hidden/system file filtering matching `tree.com`  
- Works on NTFS, ReFS, FAT, and network paths  

---

## Screen Shots

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

### Basic Usage

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
Show-Tree -Listing
```

### ASCII connector

```powershell
Show-Tree -Ascii

```

---

## Parameter Summary

| Parameter | Description |
| --- | --- |
| `-Tree` | Enables DOS compatibility mode (`-MaxDepth` `-1` `-Mono` `-NoFiles` by default). |
| `-Listing` | Compact indentation-only mode. |
| `-MaxDepth` / `-Depth` | Maximum recursion depth (`-1` = unlimited). |
| `-Recurse` | Shortcut for unlimited depth. |
| `-Mono` | Disable color. |
| `-Color` | Enable color in Tree mode. |
| `-Files` | Show files in Tree mode. |
| `-NoFiles` | Hide files. |
| `-NoGap` | Remove spacing between file and directory sections. |
| `-Ascii` | Use ASCII connectors instead of Unicode. |

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
Show-Tree -Listing | Select-String src
```

Export to a file:

```powershell
Show-Tree C:\ -Listing | Out-File listing.txt
```

---

## License

This project is licensed under the MIT License. See the LICENSE file for details.

---

## Author

**Ryan Beesley**  
Version 1.0.0  
April 2026

This module was developed as a modern, extensible reimplementation of the classic tree.com utility, with additional graphical and automation-friendly modes.
