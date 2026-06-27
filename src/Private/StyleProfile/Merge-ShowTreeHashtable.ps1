# src/Private/StyleProfile/Merge-ShowTreeHashtable.ps1

<#
.SYNOPSIS
    Deep merges two hashtables.

.DESCRIPTION
    The Merge-ShowTreeHashtable cmdlet performs a deep merge of two hashtables. Values from 
    the Override hashtable replace or extend values in the Base hashtable. If a key exists 
    in both and both values are hashtables, they are merged recursively. This is primarily 
    used for applying custom overrides to base style profiles.

.PARAMETER Base
    The base hashtable providing default values.

.PARAMETER Override
    The hashtable containing values that should override or extend the base.
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
