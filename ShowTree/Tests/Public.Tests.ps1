# ShowTree\Tests\Public.Tests.ps1

Describe "Public function test" {
    It "Show-Tree is available" {
        Get-Command Show-Tree | Should -Not -BeNullOrEmpty
    }
}
