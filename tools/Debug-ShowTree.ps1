# tools/Debug-ShowTree.ps1

Remove-Module ShowTree -Force -ErrorAction SilentlyContinue
Import-Module "$PSScriptRoot/../ShowTree/ShowTree.psd1" -Force -Verbose

Show-Tree @args
