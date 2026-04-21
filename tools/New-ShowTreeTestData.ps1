param(
    [string]$Root = ".\TestAttributes"
)

# Clean slate
if (Test-Path $Root) {
    Remove-Item $Root -Recurse -Force
}
New-Item -ItemType Directory -Path $Root | Out-Null

# Attribute sets to test
$attributeSets = @(
    @{ Name = "Normal";                Attr = [IO.FileAttributes]::Normal }
    @{ Name = "Archive";               Attr = [IO.FileAttributes]::Archive }
    @{ Name = "Hidden";                Attr = [IO.FileAttributes]::Hidden }
    @{ Name = "System";                Attr = [IO.FileAttributes]::System }
    @{ Name = "ReadOnly";              Attr = [IO.FileAttributes]::ReadOnly }
    @{ Name = "Hidden+System";         Attr = [IO.FileAttributes]::Hidden -bor [IO.FileAttributes]::System }
    @{ Name = "Hidden+ReadOnly";       Attr = [IO.FileAttributes]::Hidden -bor [IO.FileAttributes]::ReadOnly }
    @{ Name = "System+ReadOnly";       Attr = [IO.FileAttributes]::System -bor [IO.FileAttributes]::ReadOnly }
    @{ Name = "Hidden+System+ReadOnly";Attr = [IO.FileAttributes]::Hidden -bor [IO.FileAttributes]::System -bor [IO.FileAttributes]::ReadOnly }
)

# Directories
$dirRoot = Join-Path $Root "Directories"
New-Item -ItemType Directory -Path $dirRoot | Out-Null

foreach ($set in $attributeSets) {
    $path = Join-Path $dirRoot $set.Name
    $item = New-Item -ItemType Directory -Path $path
    $item.Attributes = $set.Attr
}

# Files
$fileRoot = Join-Path $Root "Files"
New-Item -ItemType Directory -Path $fileRoot | Out-Null

foreach ($set in $attributeSets) {
    $path = Join-Path $fileRoot ($set.Name + ".txt")
    $item = New-Item -ItemType File -Path $path -Value "Test file: $($set.Name)"
    $item.Attributes = $set.Attr
}

# # Mount point
# $mountPointRoot = Join-Path $Root "MountPoint"
# New-Item -ItemType Directory -Path $mountPointRoot | Out-Null

# # Get a volume GUID
# $vol = (Get-Volume | Where-Object DriveLetter -eq 'C').UniqueId

# # Create the mount point (requires Administrator)
# cmd /c "mountvol $mountPointRoot $vol"

# Symlink + Junction tests
# Convert to absolute paths for junction targets
$dirRootFull  = (Resolve-Path $dirRoot).ProviderPath
$fileRootFull = (Resolve-Path $fileRoot).ProviderPath

# (Requires Developer Mode or admin)
New-Item -ItemType SymbolicLink -Path (Join-Path $dirRootFull "Symlink") -Target $dirRootFull | Out-Null
New-Item -ItemType Junction     -Path (Join-Path $dirRootFull "Junction") -Target $dirRootFull | Out-Null

New-Item -ItemType SymbolicLink -Path (Join-Path $fileRootFull "Symlink.txt") -Target (Join-Path $fileRootFull "Hidden.txt") | Out-Null
# New-Item -ItemType Junction     -Path (Join-Path $fileRootFull "Junction.txt") -Target (Join-Path $fileRootFull "Hidden.txt") | Out-Null

Write-Host "Test attribute directory created at: $Root"
