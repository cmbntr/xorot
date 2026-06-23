## Why

The project upgraded from Zig 0.13 to Zig 0.16, and `task build` now fails before release artifacts can be produced. The break appears to come from Zig 0.16 changes in the build API and standard I/O APIs, so the project needs a small migration to restore a working build on the current toolchain.

## What Changes

- Update `build.zig` to use Zig 0.16-compatible build script APIs for executable and test setup.
- Update `src/main.zig` to use Zig 0.16-compatible stdin/stdout and reader/writer types.
- Verify and adjust the `task build` target list where Zig 0.16 target naming or support changed.
- Preserve the current CLI behavior and output semantics of `xorot` while restoring successful builds.

## Capabilities

### New Capabilities
- `zig-0-16-build-compatibility`: Defines the requirement that the project build and package successfully with Zig 0.16 while preserving existing `xorot` behavior.

### Modified Capabilities

## Impact

- Affected code: `build.zig`, `src/main.zig`, `Taskfile.yml`
- Affected systems: local development shell, cross-target release packaging via `task build`
- Dependencies: Zig 0.16 build system and stdlib I/O APIs
- User-visible impact: restores release builds without changing the `xorot` command interface
