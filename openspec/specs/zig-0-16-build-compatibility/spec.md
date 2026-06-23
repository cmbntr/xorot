# zig-0-16-build-compatibility Specification

## Purpose
TBD - created by archiving change fix-zig-0-16-build. Update Purpose after archive.
## Requirements
### Requirement: Project builds with Zig 0.16
The project SHALL compile successfully with Zig 0.16 using the repository's build script and current development environment configuration.

#### Scenario: Native build succeeds
- **WHEN** a developer runs `zig build`
- **THEN** Zig 0.16 accepts the build script and compiles the `xorot` executable without build API or stdlib I/O migration errors

### Requirement: Release build task remains functional
The project SHALL keep `task build` as the release entry point and SHALL produce packaged release outputs for each supported target in the configured target matrix for the current execution environment.

#### Scenario: Release task completes for supported targets locally
- **WHEN** a developer runs `task build` outside GitHub Actions
- **THEN** each configured local supported target completes `zig build install`
- **AND** each successful target output is packaged into the expected `release/` zip artifact

#### Scenario: Release task completes for supported targets in GitHub Actions
- **WHEN** GitHub Actions runs `task build`
- **THEN** each configured GitHub Actions supported target completes `zig build install`
- **AND** each successful target output is packaged into the expected `release/` zip artifact
- **AND** the GitHub Actions target set excludes macOS targets

### Requirement: xorot streaming behavior remains unchanged
The Zig 0.16 migration SHALL preserve the existing stdin-to-stdout streaming behavior of `xorot`, including buffered processing and byte-for-byte transformation semantics.

#### Scenario: Standard input is transformed and written to standard output
- **WHEN** `xorot` receives bytes on stdin
- **THEN** it reads input in buffered chunks
- **AND** it applies the existing ROT/XOR/ROT byte transformation sequence in the same order as before
- **AND** it writes the transformed bytes to stdout without requiring changes to the command interface

### Requirement: Target matrix uses Zig 0.16-compatible target names
The release target list SHALL use target names accepted by Zig 0.16 for every target kept in the supported release matrix for the current execution environment.

#### Scenario: Taskfile target names are valid locally
- **WHEN** `task build` iterates over the configured local targets
- **THEN** Zig 0.16 recognizes each target string as valid input to `-Dtarget`

#### Scenario: Taskfile target names are valid in GitHub Actions
- **WHEN** `task build` iterates over the configured GitHub Actions targets
- **THEN** Zig 0.16 recognizes each target string as valid input to `-Dtarget`

