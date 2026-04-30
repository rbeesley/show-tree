# ShowTree

A modern PowerShell-native replacement for the classic `tree.com` command.

ShowTree provides three display modes:

- **Normal mode** (default): graphical Unicode tree with color, files, and depth control  
- **Tree mode** (`-Mode Tree`, ~~`-Tree`~~): faithful DOS `tree.com` compatibility  
- **Listing mode** (`-Mode List`, ~~`-List`~~): compact, indentation-only output ideal for piping, grepping, and exporting  

## Install

```powershell
Install-Module ShowTree
```

### Basic Usage

```powershell
Show-Tree
Show-Tree -Mode Tree
Show-Tree -Mode List
Show-Tree -Exclude '.git' -Include '.git*'
```

### Mode Selection

You can select a mode using either:

```powershell
-Mode Normal|Tree|List
```

~~or the backward-compatible switches:~~ (deprecated)

```powershell
-Tree
-List
```

Normal mode is used when no mode is specified.

## Examples

```powershell
Show-Tree C:\Projects
Show-Tree C:\Windows -Mode Tree -Files
Show-Tree -Mode List -NoFiles
```

For full documentation, screenshots, and advanced usage, visit the GitHub repository.
