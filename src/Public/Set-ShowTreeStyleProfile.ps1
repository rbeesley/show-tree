# src/Public/Set-ShowTreeStyleProfile.ps1

function Set-ShowTreeStyleProfile {
    [CmdletBinding(DefaultParameterSetName = 'Path')]
    param(
        [Parameter(ParameterSetName = 'Path')]
        [string] $Path,

        [Parameter(ParameterSetName = 'Path')]
        [string] $Culture,

        [Parameter(ParameterSetName = 'InputObject')]
        [System.Collections.IDictionary] $InputObject,

        [Parameter(ParameterSetName = 'Reset', Mandatory)]
        [switch] $Reset
    )

    switch ($PSCmdlet.ParameterSetName) {
        'Reset' {
            $script:ShowTreeState.StyleProfile = Get-ShowTreeStyleProfile
            return
        }

        'Path' {
            $script:ShowTreeState.StyleProfile = Get-ShowTreeStyleProfile -Path $Path -Culture $Culture
            return
        }

        'InputObject' {
            $baseProfile = Get-ActiveShowTreeStyleProfile
            $script:ShowTreeState.StyleProfile = Merge-ShowTreeHashtable -Base $baseProfile -Override $InputObject
            return
        }
    }
}
