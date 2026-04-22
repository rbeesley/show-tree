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
Show-Tree -Exclude '.git' -Include '.git*'
```

For full documentation, screenshots, and advanced usage, visit the GitHub repository.
