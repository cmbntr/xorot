## Why

The repository currently builds and releases correctly as a Zig CLI, but it does not declare package metadata through `build.zig.zon`. That leaves the project without a canonical package version, package identity, or explicit package file set for Zig package consumers.

## What Changes

- Add a root `build.zig.zon` manifest for the `xorot` package.
- Set the package version to `0.3.0` and the minimum Zig version to `0.16.0`.
- Declare that the package currently has no external Zig dependencies.
- Define the package file set explicitly so downstream package hashing and fetching include only the intended project files.
- Let Zig generate and persist the package fingerprint as the stable package identity.

## Capabilities

### New Capabilities
- `zig-package-metadata`: Defines the required package manifest metadata and package file boundaries for this repository.

### Modified Capabilities

## Impact

- Affected code: new root `build.zig.zon` file only for this change.
- Affected systems: Zig package metadata, package hashing, and downstream fetch/use as a package.
- Dependencies: no new runtime or build dependencies.
- APIs: no CLI behavior changes and no new library API exposure in this change.
