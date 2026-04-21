param(
    [string]$Root = ".\TestAttributes"
)

$familyRoot = Join-Path $Root "FamilyRelations"

# Reset
if (Test-Path $familyRoot) {
    Remove-Item $familyRoot -Recurse -Force
}
New-Item -ItemType Directory -Path $familyRoot | Out-Null

# Child type definitions
$childTypes = @(
    'Empty',
    'File',
    'Subdir',
    'FileAndSubdir'
)

# Safe rotation
function Rotate-List {
    param(
        [array]$List,
        [int]$Offset
    )

    $count = $List.Count
    $result = @()

    for ($i = 0; $i -lt $count; $i++) {
        $result += $List[($i + $Offset) % $count]
    }

    return $result
}

# Create a node with amplified contents
function New-FRNode {
    param(
        [string]$Parent,
        [string]$Name,
        [string]$Type
    )

    $path = Join-Path $Parent $Name
    New-Item -ItemType Directory -Path $path | Out-Null

    switch ($Type) {
        'File' {
            New-Item -ItemType File -Path (Join-Path $path "File1.txt") | Out-Null
            New-Item -ItemType File -Path (Join-Path $path "File2.txt") | Out-Null
        }
        'Subdir' {
            New-Item -ItemType Directory -Path (Join-Path $path "Subdir1") | Out-Null
            New-Item -ItemType Directory -Path (Join-Path $path "Subdir2") | Out-Null
        }
        'FileAndSubdir' {
            New-Item -ItemType File -Path (Join-Path $path "File1.txt") | Out-Null
            New-Item -ItemType File -Path (Join-Path $path "File2.txt") | Out-Null
            New-Item -ItemType Directory -Path (Join-Path $path "Subdir1") | Out-Null
            New-Item -ItemType Directory -Path (Join-Path $path "Subdir2") | Out-Null
        }
        'Empty' { }
    }
}

# Parents A–E
$parents = 'A','B','C','D','E'

for ($i = 0; $i -lt $parents.Count; $i++) {

    $parentName = $parents[$i]
    $parentPath = Join-Path $familyRoot $parentName
    New-Item -ItemType Directory -Path $parentPath | Out-Null

    # Rotate child types safely
    $rotated = Rotate-List -List $childTypes -Offset $i

    # Create children 1–4
    for ($j = 0; $j -lt $rotated.Count; $j++) {
        $childName = "{0}_{1}" -f ($j+1), $rotated[$j]
        New-FRNode -Parent $parentPath -Name $childName -Type $rotated[$j]
    }
}
