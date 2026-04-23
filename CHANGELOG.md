# Changelog

All notable changes to **ShowTree** will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),  
and this project adheres to [Semantic Versioning](https://semver.org/).

---

## [1.1.2] - 2026-04-22

### Added

### Changed

- Version bump (documentation, non-functional) to make documentation visible on PowerShell Gallery

### Fixed

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

- Full gap‑logic engine with support for:
  - Internal gaps (files → directories)
  - Tail gaps (end‑of‑block spacing)
  - Sibling/cousin gaps (between directory blocks)
  - Depth‑aware gap suppression
  - Reparse‑point‑aware gap suppression
- Inline documentation across all internal functions.
- Region markers for improved navigation and maintainability.
- Accurate path‑casing normalization for all platforms.
- Attribute‑aware color styling with override support.
- Optional reparse‑point target display (`-ShowTargets`).
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
- Improved Listing mode to be more script‑friendly and predictable.

### Fixed

- Incorrect sibling gap rendering when depth‑capped directories appeared non‑empty.
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
