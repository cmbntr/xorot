## Why

The current file-processing code works, but it grants broader file access than needed in one in-place write path and leaves the internal fixed buffer size at a conservative 8 KiB default. Narrowing access intent and adopting a larger fixed chunk size improves clarity and operational safety without changing the transform algorithm or CLI surface.

## What Changes

- Narrow file open modes to least-privilege settings that match actual operations in copy/output and in-place processing.
- Harden file opens against accidentally treating directories as regular files where Zig's APIs allow that intent to be expressed.
- Increase the fixed processing buffer size from 8 KiB to 64 KiB across the shared processing paths and update tests that depend on the buffer boundary.
- Preserve current destination creation behavior, including default created-file permissions governed by Zig's standard create-file defaults and process `umask`.

## Capabilities

### New Capabilities
- None.

### Modified Capabilities
- `cli-file-processing`: clarify least-privilege file access expectations for file modes and pin the shared fixed chunk size to 64 KiB.

## Impact

- Affected code: `src/main.zig` file open/create paths, buffer constant, and buffer-boundary tests.
- APIs: no new CLI flags, runtime configuration, or external interfaces.
- Dependencies: none.
- Systems: file I/O behavior remains streaming and bounded-memory, with fewer I/O calls expected for larger files due to the larger fixed chunk size.
