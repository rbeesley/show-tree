# Changelog

All notable changes to **ShowTree** will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),  
and this project adheres to [Semantic Versioning](https://semver.org/).

---

## [1.2.1] - 2026-04-30

### Fixed

- Corrected caller-relative path resolution so that `Show-Tree .` resolves against
  the caller’s working directory rather than the module’s import directory.
- Fixed behavior when the module is auto-imported from `$PSModulePath`, ensuring
  relative paths no longer resolve to the module installation directory.
- Updated `Resolve-TreePath` to use the caller’s session state and simplified the
  path pipeline for correctness and maintainability.
- Corrected `Get-NormalizedPath` so it no longer destroys relativity before
  normalization.
- Fixed Pester tests to correctly simulate caller semantics and avoid false
  negatives caused by module session isolation.
- `-Include` and `-Exclude` parameters were accidently removed from v1.2.0, and were
  added back to restore the broken functionality.

### Changed

- Moved `Resolve-TreePath` into `PathUtilities.ps1` for clearer structure and
  separation of concerns.
- Simplified path resolution logic: `Resolve-TreePath` now owns caller-relative
  behavior and error handling; `Get-NormalizedPath` now assumes absolute paths
  and focuses solely on casing/segment normalization.
- Updated test suite to distinguish between private helper tests (module scope)
  and caller-behavior tests (outside module scope).

### Notes

This release focuses on correctness and predictability of path handling,
especially when the module is installed from the PowerShell Gallery. All public
behavior remains backward compatible.

---

## [1.2.0] - 2026-04-30

### Added

- New `-Mode` parameter (`Normal`, `Tree`, `List`) for explicit mode selection.
- Backward-compatible aliases `-Tree` and `-List` now map to `-Mode Tree` and `-Mode List`.
- Mode resolution logic with clear, predictable behavior and no accidental mode switching.
- Pester test suite for path resolution, mode binding, and paired-switch validation.
- Internal helper `Resolve-TreePath` with full test coverage.
- Structured private helper files under `Private\` for filtering, rendering, gap logic, connectors, styles, and path utilities.

### Changed

- `-Tree` and `-List` are now **deprecated** but still supported.
- `-Mode List` replaces the previous `Listing` name for consistency.
- `-Color` is now allowed in Normal mode and simply forces color on.
- Paired switches (e.g., `-Color`/`-Mono`, `-Files`/`-NoFiles`) now validate mutual exclusivity.
- Effective settings are now computed based on `$Mode` instead of parameter sets.
- README updated to reflect new mode system and deprecations.
- PowerShell Gallery description updated for clarity and accuracy.

### Fixed

- **Resolved major path-resolution bug** where relative paths were incorrectly resolved when the module was installed from the PowerShell Gallery.
- Normalized path handling now guarantees rooted paths before resolution.
- Tree mode now correctly reproduces `tree.com` error behavior for invalid drives and paths.
- Several internal helpers updated to use `$Mode` instead of `$Tree`/`$List`.

### Removed

- Parameter-set-based mode selection (replaced by unified `-Mode` system).
- Monolithic `Show-TreeInternal.ps1` structure (replaced with modular private helpers).

### Notes

This release focuses on correctness, predictability, and maintainability.  
All public behavior remains backward compatible, but internal logic has been significantly modernized.

---

## [1.1.3] - 2026-04-29

### Added

- Started creating Pester files to help catch subtle changes in the future

### Fixed

- Missing a Gap Connector between files and directories

---

## [1.1.2] - 2026-04-22

### Changed

- Version bump (documentation, non-functional) to make documentation visible on PowerShell Gallery

---

## [1.1.1] - 2026-04-22

### Added

- New `Get-FilteredTreeItems` engine providing:
  - Stable-order filtering for directories and files
  - Hidden/System filtering with Include override support
  - Exact-match and glob-match Include/Exclude semantics
  - Correct precedence rules (Exact Exclude > Glob Include, etc.)
  - Consistent behavior across Normal, Tree, and Listing modes
- Documentation for `-Include` and `-Exclude` parameters.
- Inline documentation for filtering logic and precedence rules.

### Changed

- Tree.com mode now prints the resolved path directly and correctly handles
  invalid-path reporting.
- Root rendering in Normal/Listing modes now uses a local `$colorReset`
  instead of referencing internal engine variables.
- Improved internal consistency of parameter naming and comment blocks.
- Minor cleanup of connector rendering and attribute debug formatting.

### Fixed

- Hidden/System filtering no longer permanently removes items before Include
  patterns are evaluated.
- Include-only filtering no longer removes all items unintentionally.
- Exact Exclude patterns no longer get overridden by broader Include globs.
- Filtering now correctly preserves original enumeration order.
- Fixed a bug where `$normalized` was referenced after being commented out.
- Fixed trailing-space issues in Write-TreeItem output.

---

## [1.1.0] - 2026-04-21

### Added

- Full gap-logic engine with support for:
  - Internal gaps (files → directories)
  - Tail gaps (end-of-block spacing)
  - Sibling/cousin gaps (between directory blocks)
  - Depth-aware gap suppression
  - Reparse-point-aware gap suppression
- Inline documentation across all internal functions.
- Region markers for improved navigation and maintainability.
- Accurate path-casing normalization for all platforms.
- Attribute-aware color styling with override support.
- Optional reparse-point target display (`-ShowTargets`).
- New `Show-TreeLegend` command for color/style visualization.

### Changed

- Major refactor of `Show-TreeInternal.ps1`:
  - Unified parameter formatting (`-Switch:$value`, `-Name value`).
  - Reordered functions into logical regions.
  - Consolidated connector logic and removed duplication.
  - Improved recursion prefix handling.
  - Cleaned up indentation, alignment, and readability.
- Improved Tree.com compatibility mode:
  - Raw Win32 enumeration for exact ordering.
  - Accurate volume label and serial number retrieval.
- Improved Listing mode to be more script-friendly and predictable.

### Fixed

- Incorrect sibling gap rendering when depth-capped directories appeared non-empty.
- Tail gap incorrectly triggering sibling gap suppression in some cases.
- Reparse points incorrectly treated as expandable directories.
- Several edge cases involving hidden/system filtering.
- Prefix alignment issues in mixed file/directory blocks.

---

## [1.0.1] - 2025-04-18

### Added

- Initial PowerShell Gallery release.
- Unicode and ASCII connector support.
- Tree.com compatibility mode (`-Tree`).
- Listing mode (`-List`) for compact output.
- Depth control (`-MaxDepth`, `-Depth`, `-Recurse`).
- File inclusion/exclusion (`-Files`, `-NoFiles`).
- Hidden/system filtering.
- Basic color styling.

### Fixed

- Various early formatting and alignment issues.
- Improved error handling for invalid paths.

---

## [1.0.0] - 2025-04-18

### Added

- First public GitHub release.
- Core directory tree rendering engine.
- Basic Unicode connector support.
- Initial color profile system.
