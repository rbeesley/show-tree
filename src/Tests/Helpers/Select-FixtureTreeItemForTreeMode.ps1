# 
# $items = @(
#    New-FixtureTreeItem -Name 'a'  -IsDirectory $true  -Depth 0 -ParentPath 'C:\Test'
#    New-FixtureTreeItem -Name 'ab' -IsDirectory $false -Depth 1 -ParentPath 'C:\Test\a'
#    New-FixtureTreeItem -Name 'aa' -IsDirectory $true  -Depth 1 -ParentPath 'C:\Test\a'
#    New-FixtureTreeItem -Name 'aa1' -IsDirectory $false -Depth 2 -ParentPath 'C:\Test\a\aa'
#    New-FixtureTreeItem -Name 'b'  -IsDirectory $true  -Depth 0 -ParentPath 'C:\Test'
#    New-FixtureTreeItem -Name 'b1' -IsDirectory $false -Depth 1 -ParentPath 'C:\Test\b'
# )
#
# -or
#
# $structure = [ordered]@{
#    a = [ordered]@{
#        aa = $null
#        ab = [ordered]@{
#            ab1 = $null
#        }
#    }
#    b = [ordered]@{
#        b1 = $null
#    }
# }
# $items = New-FixtureTree -Structure $structure | Select-FixtureTreeItemForTreeMode
#

function Select-FixtureTreeItemForTreeMode {
    param(
        [Parameter(ValueFromPipeline)]
        $InputObject
    )

    process {
        foreach ($item in $InputObject) {
            $item

            if ($item.Children) {
                $children = @($item.Children)
                $files = @($children | Where-Object { -not $_.IsContainer })
                $directories = @($children | Where-Object { $_.IsContainer })

                foreach ($file in $files) {
                    $file
                }

                foreach ($directory in $directories) {
                    $directory | Select-FixtureTreeItemForTreeMode
                }
            }
        }
    }
}