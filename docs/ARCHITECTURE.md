# ShowTree Architecture

This document describes the internal design, build system, and development workflows for the **ShowTree** module.

## Core Concepts

ShowTree is built around a decoupled streaming architecture. It separates the discovery of filesystem items from their visual representation, allowing for high performance and consistent behavior across different display modes.

### 1. Data Structures

The module uses three primary internal data structures (defined via `PSTypeName` on custom objects):

- **ShowTree.TreeItem**: Represents a single filesystem object (File, Directory, Symlink, etc.). It captures metadata like attributes, link targets, and platform-specific states.
- **ShowTree.TreeLayout**: Contains structural metadata for an item relative to its position in the tree, such as `Depth`, `IsLastSibling`, and `AncestorIsLastSibling` (used to draw vertical span lines).
- **ShowTree.TreeRecord**: The unit of communication between the engine and the renderer. A record can be an `Item` (containing a `TreeItem` and its `TreeLayout`) or a `Gap` (containing only a `TreeLayout` for spacing).

### 2. The Traversal Engine

Discovery is handled by `Get-TreeItem` (the public entry point) and `Invoke-TreeTraversal` (the recursive engine).

- **Providers**: Enumeration is abstracted via `TreeChildProvider` objects.
  - **Win32 Provider**: Uses P/Invoke (`FindFirstFile`) for raw, high-performance enumeration on Windows, matching the exact ordering of `tree.com`.
  - **PowerShell Provider**: Uses `Get-ChildItem` for cross-platform compatibility and support for non-filesystem providers.
- **Child Retrieval**: `Get-TreeChild` acts as a middle-layer that fetches children from a provider and applies visibility filtering before returning them to the traversal engine.
- **Pruning & Visibility**: Filtering logic (`Test-TreeItemVisible`, `Test-TreeItemRecurse`) handles glob patterns, hidden/system attributes, and "structural rescue" (keeping ancestor directories visible if they contain matching children).

### 3. The Rendering Pipeline

The renderer (`Format-Tree`) consumes a stream of `TreeRecord` objects.

- **Connectors**: `Get-Connector` retrieves the appropriate symbols (Unicode or ASCII) based on the current mode and structural state.
- **Styling**: `Get-ItemStyle` resolves ANSI colors by merging base styles with state-based overlays (e.g., Hidden + Directory) according to a defined `StylePriority` in the style profile.

---

## Build System

ShowTree uses a 100% PowerShell build system based on the [Invoke-Build](https://github.com/nightroman/Invoke-Build) framework.

### Entry Point
The primary entry point is `build.ps1` in the project root. It handles requirement bootstrapping and task execution.

```powershell
# Run the default build (Test)
.\build.ps1

# Install build dependencies and run tests
.\build.ps1 -Bootstrap

# Run a specific task (e.g., Compile/Distribution)
.\build.ps1 -Task Dist
```

  ---

  ### Key Tasks

  - **Build**: Fingerprints the source and performs an incremental build, including transpilation for the Desktop edition.
  - **Test**: Executes the Pester 5 test suite.
  - **BuildDist**: Packages the module into the `dist/ShowTree` folder for release, ensuring PowerShell Gallery compatibility.

  ---

## Test System

The project uses [Pester 5](https://pester.dev/) for unit and integration testing. Tests are located in `src/Tests/Unit/` and organized by subsystem.

### Test Fixtures

To ensure consistent results regardless of the host OS, many tests use a **Fixture Tree**. This is a mocked filesystem structure created in memory using `New-FixtureTree`, allowing for complex scenarios (mixed files, symlinks, gaps) to be tested without actual disk I/O.

### Validation Workflows

- **Standard Unit Tests**: Validate logic in isolation (filtering, styling, etc.).
- **Rendering Tests**: Use the fixture engine to verify the exact character-by-character string output of various modes.
- **Cross-Platform Validation**: Tests are designed to run on both Windows and Linux, specifically accounting for differences in path separators and file attributes.