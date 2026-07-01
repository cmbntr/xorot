## Why

Pipe mode currently constructs stdin/stdout adapters with the default positional-first file reader/writer APIs even though those handles are stream-like on supported platforms. This causes avoidable fallback work at process startup, and the project can remove that overhead with a small low-risk change while preserving current behavior and the shared `processCore` processing path.

## What Changes

- Update pipe mode to use streaming stdio constructors for stdin and stdout instead of the default positional-first constructors.
- Preserve the existing shared `processCore` transform loop and 64 KiB chunking semantics across pipe and file processing.
- Add implementation-time performance measurement steps and record baseline/results in sibling change files (`perf-before.md` and `perf-after.md`).

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `cli-file-processing`: clarify that pipe mode keeps the shared processing core while using streaming stdio adapters, and require implementation work to capture before/after performance notes for the change.

## Impact

- Affected code: `src/main.zig` pipe-mode stdio construction and adjacent tests.
- Affected behavior: no intended CLI, output, chunk-size, or file-mode semantic changes.
- Affected process: implementation should produce `perf-before.md` and `perf-after.md` beside the change artifacts to document measured impact.
