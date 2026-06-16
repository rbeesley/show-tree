# src/Private/StyleProfile/Merge-ShowTreeHashtable.ps1

<#
.SYNOPSIS
    Deep merges two hashtables.

.DESCRIPTION
    The Merge-ShowTreeHashtable cmdlet performs a deep merge of two hashtables, where values from
    the Override hashtable replace or extend values in the Base hashtable. This is used for
    combining style profiles and overrides.
#>
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
