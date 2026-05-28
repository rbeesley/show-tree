# src/Public/Select-TreeItem.ps1

function Select-TreeItem {
    [CmdletBinding(DefaultParameterSetName='Default')]
    param(
        [Parameter(ValueFromPipeline)]
        [object[]] $InputObject,

        [string[]] $Name,
        [scriptblock] $FilterScript,

        [ValidateSet('Children','Descendants')]
        [string] $Expand,

        [switch] $NoRoot,

        [switch] $Flatten,

        [int] $First,
        [int] $Last,
        [int] $Skip,
        [int] $SkipLast,
        [int[]] $Index,

        [switch] $Unique
    )

    begin {
        $inputList = New-Object System.Collections.Generic.List[object]

        function Walk {
            param(
                $Node,
                [System.Collections.Generic.List[object]] $Results,
                [string] $ExpandMode
            )

            switch ($ExpandMode) {
                'Children' {
                    foreach ($child in $Node.Children) {
                        $Results.Add($child)
                    }
                }

                'Descendants' {
                    $Results.Add($Node)
                    foreach ($child in $Node.Children) {
                        Walk -Node $child -Results $Results -ExpandMode $ExpandMode
                    }
                }
            }
        }
    }

    process {
        foreach ($obj in $InputObject) {
            $inputList.Add($obj)
        }
    }

    end {
        # 1. Handle -Flatten (semantic shortcuts)
        #
        if ($NoRoot) {
            # Force expand mode
            $Expand = 'Descendants'

            # Force skip behavior
            $Skip = 1
        }

        if ($Flatten) {
            $Expand = 'Descendants'
        }

        #
        # 2. Build the base sequence
        #
        if ($Expand) {
            $results = New-Object System.Collections.Generic.List[object]
            foreach ($root in $inputList) {
                Walk -Node $root -Results $results -ExpandMode $Expand
            }
            $items = $results.ToArray()
        }
        else {
            # No expand → treat input as flat list
            $items = $inputList.ToArray()
        }

        #
        # 3. Apply Name / FilterScript
        #
        if ($Name) {
            $items = $items | Where-Object { $_.Name -in $Name }
        }

        if ($FilterScript) {
            $items = $items | Where-Object $FilterScript
        }

        #
        # 4. Unique
        #
        if ($Unique) {
            $items = $items | Sort-Object FullPath -Unique
        }

        #
        # 5. Slicing — let Select-Object do the work
        #
        $selectParams = @{}
        if ($First)    { $selectParams.First    = $First }
        if ($Last)     { $selectParams.Last     = $Last }
        if ($Skip)     { $selectParams.Skip     = $Skip }
        if ($SkipLast) { $selectParams.SkipLast = $SkipLast }
        if ($Index)    { $selectParams.Index    = $Index }

        if ($selectParams.Count -gt 0) {
            $items = $items | Select-Object @selectParams
        }

        return $items
    }
}
