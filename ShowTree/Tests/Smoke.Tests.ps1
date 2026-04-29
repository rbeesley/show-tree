# ShowTree\Tests\Smoke.Tests.ps1

Describe "Pester smoke test" {
    It "Runs a basic test" {
        1 | Should -Be 1
    }
}
