# ShowTree Build Architecture

ShowTree uses a 100% PowerShell-based build system powered by the [Invoke-Build](https://github.com/nightroman/Invoke-Build) framework. It provides a task-driven workflow that handles everything from environment bootstrapping to distribution packaging.

## The Task-Driven Workflow

The build process is defined in `build/tasks.build.ps1` and exposed via the `build.ps1` helper in the root.

### Incremental Build and Caching

Similar to the test system, the build process is optimized to avoid redundant work. It uses a **fingerprinting mechanism** to determine if a build is current.

1. **Source Tracking**: The system calculates a hash of the `src/` directory.
2. **Build State**: This hash is compared against a value stored in the last successful build's metadata.
3. **Smart Rebuilds**: If the source hasn't changed, time-consuming tasks like transpilation and documentation generation are skipped.

### Bootstrapping

The `build.ps1` script features a `-Bootstrap` switch. This uniquely automates the setup of the development environment by:

- Importing the `requirements.psd1` file.
- Verifying the presence and version of required PowerShell modules (e.g., Pester, Invoke-Build).
- Installing missing dependencies into the `CurrentUser` scope automatically.

## Automation and Developer Experience

### Recursive Test Discovery

The build script simplifies complex test hierarchies by walking the `src/Tests` tree. When using `./build.ps1 -Test <Pattern>`, the system searches all subdirectories for matching `.Tests.ps1` files. This allows the project to maintain a highly organized test structure (e.g., grouping by functional area like `Rendering` or `PathUtilities`) without requiring the developer to know the exact file path to run a test.

### Task Independence

While the build is primarily linear (Compile -> Test -> Dist), tasks can be run independently for rapid iteration. The use of fingerprinting ensures that running `./build.ps1 -Task Test` only triggers a re-compilation if the source code has actually changed.

## Transpilation and Cross-Version Compatibility

One of the most innovative parts of the ShowTree build system is the **Transpilation Engine** (`build/Transpile-Source.ps1`).

### The Problem

PowerShell 7 introduced several high-productivity operators (like the null-coalescing assignment `??=` and the ternary operator `? :`) that are not available in PowerShell 5.1 or older versions of PowerShell Core.

### The Solution: Source-to-Source Transformation

Instead of limiting the source code to the "lowest common denominator" of syntax, ShowTree uses a custom transpiler that runs during the `Compile` task. It performs rules-based transformations to convert modern syntax into legacy-compatible logic:

- **Null-Coalescing Assignment**: `$a ??= $b` is transformed into `if ($null -eq $a) { $a = $b }`.
- **Ternary Operator**: `$a ? $b : $c` is transformed into a scoped script block: `(&{if($a){$b}else{$c}})`.
- **Static New**: `[Type]::new()` calls are transformed into `New-Object` calls for environments where static constructors have stricter requirements.

This allows ShowTree to be developed using modern best practices while remaining 100% compatible with **Windows PowerShell 5.1** and **PowerShell Core 6.0+**. Because this approach is modularly driven by rules, so it can be extended to support additional syntax transformations in the future.

## Distribution Workflow

The `Dist` task is the final stage of the build process.

1. **Staging**: A clean `dist/` directory is created.
2. **Assembly**: The module manifest (`.psd1`) and the root module (`.psm1`) are copied over.
3. **Internalized Source**: All private and public script files are processed by the transpiler and flattened into the distribution folder.
4. **Validation**: The build system runs a specialized suite of smoke tests (`build/Test-WindowsPowerShellDist.ps1`) against the transpiled code in a Windows PowerShell 5.1 environment to ensure no syntax regressions were introduced. This does not detect any functional validation but it helps to quickly identify any transpilation issues.
