# ShowTree Test Architecture

The ShowTree test system is designed to provide high-fidelity validation of internal module logic while maintaining a fast, iterative development loop. It solves the "stale module" problem common in PowerShell development through an intelligent, hash-based import system.

## The Import-ModuleUnderTest Workflow

Standard PowerShell module testing often suffers from session state issues where changes to the source code are not reflected in the active session. ShowTree uses a custom helper, `Import-ModuleUnderTest.ps1`, to manage this.

### Hash-Based Change Detection

Instead of blindly removing and re-importing the module, the system calculates a cryptographic hash of all relevant source files (`.ps1`, `.psm1`, `.psd1`, and `.psd1` data files).

1. **Fingerprinting**: `Get-ModuleSourceFingerprint.ps1` walks the `src/` tree, excluding tests, and generates a composite hash.
2. **State Storage**: This hash is stored in the module's `PrivateData` when it is first imported.
3. **Selective Reloading**: On subsequent calls (even within the same Pester run), the helper compares the current disk fingerprint against the loaded module's stored fingerprint. If they differ, the module is forcibly removed and re-imported.

This ensures that every test block runs against the exact version of the code currently on disk, without the performance penalty of unnecessary reloads.

## In-Module Testing Strategy

To maintain a clean public API, most of ShowTree's logic resides in private functions. The test suite uses `InModuleScope` to "reach inside" the module.

### Accessing Private Logic

By wrapping tests in `InModuleScope ShowTree`, Pester can execute internal functions directly. This allows us to unit test components like `Get-TreeChild` or `Merge-ShowTreeHashtable` without exporting them.

### Fixture Trees (The Memory Filesystem)

A major innovation in the ShowTree test suite is the **Fixture Tree** engine. Testing filesystem logic across Windows and Linux is notoriously difficult due to differences in separators, attributes, and permissions.

Instead of creating real files on disk (which is slow and leaves artifacts), we use `New-FixtureTree` to build an in-memory graph of `ShowTree.TreeItem` objects.

1. **Deterministic Input**: We define a nested hashtable representing the desired filesystem structure.
2. **Provider Mocking**: The `New-TestTreeChildProvider` helper creates a mock provider that serves items from the memory graph instead of the disk.
3. **High-Fidelity Rendering Tests**: This allows us to verify character-perfect rendering of complex tree structures (including gaps and vertical spans) in a completely platform-agnostic way.

### Mocking Internal State

Since the module maintains a global state for the active Style Profile, the test suite frequently mocks `Get-ActiveShowTreeStyleProfile` to inject specific color configurations for rendering validation.

## Test Orchestration and Automation

The test system is fully integrated into the build script, allowing for a single entry point for all development tasks.

### The ./build.ps1 Entry Point

This centralizes the logic for:

1. Ensuring the `Import-ModuleUnderTest` logic is correctly initialized.
2. Standardizing the output for CI/CD environments.

### Selective Test Execution

The build system allows for selective test runs via the `-Test` parameter. This works by recursively walking the `src/Tests/Unit` tree to find files matching the pattern.

For example, `./build.ps1 -Test Filtering` will automatically locate and execute `src/Tests/Unit/Filtering/Filtering.Tests.ps1`, regardless of its location in the test hierarchy.

### Physical Fixture Generation (New-ShowTreeTestData.ps1)

While memory-based fixtures are preferred for speed, certain low-level behaviors (like Win32 attribute detection) must be tested against a real filesystem. While it isn't used for any of the automated tests, so that there aren't any external dependencies on tests, and they are then more reliable. Having a tool to generate complex filesystem structures greatly improves manual testing. The `tools/New-ShowTreeTestData.ps1` script manages this:

1. **Safety Checks**: The script validates the target root to prevent accidental modification of sensitive system directories.
2. **Cross-Platform Attributes**: It applies attributes selectively based on the host OS. On Windows, it uses P/Invoke to set System and Hidden bits; on Linux, it uses `chmod` to set executable bits, setuid, setgid, and sticky bits.
3. **Metadata Indexing**: It generates a `metadata-index.json` file in the fixture root. This allows tests to programmatically verify the expected state of the "physical" files without hardcoding platform-specific logic into the Pester tests themselves.

### Conclusion

By combining high-speed memory-based filesystem simulation with physical fixture generation and a strictly verified module import cache, the ShowTree test architecture provides the safety of a compiled-language test suite with the flexibility and speed of PowerShell scripting.
