# src\Private\Merge-ShowTreeHashtable.ps1

function Merge-ShowTreeHashtable {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Collections.IDictionary] $Base,

        [Parameter(Mandatory)]
        [System.Collections.IDictionary] $Override
    )

    $result = @{}

    foreach ($key in $Base.Keys) {
        $value = $Base[$key]

        if ($value -is [System.Collections.IDictionary]) {
            $child = @{}
            foreach ($childKey in $value.Keys) {
                $child[$childKey] = $value[$childKey]
            }
            $result[$key] = $child
        }
        else {
            $result[$key] = $value
        }
    }

    foreach ($key in $Override.Keys) {
        if (
            $result.Contains($key) -and
            $result[$key] -is [System.Collections.IDictionary] -and
            $Override[$key] -is [System.Collections.IDictionary]
        ) {
            $result[$key] = Merge-ShowTreeHashtable -Base $result[$key] -Override $Override[$key]
        }
        else {
            $result[$key] = $Override[$key]
        }
    }

    return $result
}
