# zig-package-metadata Specification

## Purpose
TBD - created by archiving change add-build-zig-zon-metadata. Update Purpose after archive.
## Requirements
### Requirement: Root Zig package manifest exists
The repository SHALL include a root `build.zig.zon` manifest so the project has explicit Zig package metadata and a stable package identity.

#### Scenario: Manifest is present at package root
- **WHEN** a maintainer inspects the repository root
- **THEN** a `build.zig.zon` file exists alongside `build.zig`

### Requirement: Manifest declares canonical package metadata
The `build.zig.zon` manifest SHALL declare the package name as `xorot`, the package version as `0.3.0`, the minimum Zig version as `0.16.0`, and an empty dependency set.

#### Scenario: Metadata fields match agreed values
- **WHEN** the `build.zig.zon` file is read
- **THEN** it declares `.name = .xorot`
- **AND** it declares `.version = "0.3.0"`
- **AND** it declares `.minimum_zig_version = "0.16.0"`
- **AND** it declares `.dependencies = .{}`

### Requirement: Manifest constrains package contents explicitly
The `build.zig.zon` manifest SHALL declare an explicit package file allow-list so package hashing and downstream fetches include only the intended package files.

#### Scenario: Package file set is limited to intended files
- **WHEN** the `build.zig.zon` file is read
- **THEN** its `.paths` field includes `build.zig`
- **AND** its `.paths` field includes `build.zig.zon`
- **AND** its `.paths` field includes `src`
- **AND** its `.paths` field includes `README.md`
- **AND** its `.paths` field includes `LICENSE`

### Requirement: Package fingerprint is toolchain-generated
The package fingerprint SHALL come from Zig's toolchain-generated suggestion rather than being invented manually so the committed manifest preserves a stable toolchain-assigned package identity.

#### Scenario: Missing fingerprint yields a toolchain suggestion
- **WHEN** a maintainer adds the initial manifest without a fingerprint and runs `zig build`
- **THEN** Zig reports that the top-level `.fingerprint` field is missing
- **AND** Zig prints a suggested fingerprint value to use
- **WHEN** the maintainer copies that suggested value into `build.zig.zon` and reruns `zig build`
- **THEN** the build succeeds with the committed toolchain-generated fingerprint

