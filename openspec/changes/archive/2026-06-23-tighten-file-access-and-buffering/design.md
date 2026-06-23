## Context

`src/main.zig` already separates copy/output mode from in-place mode and uses Zig 0.16 `std.Io.Dir.cwd().openFile` / `createFile` with fixed-size stack buffers. The current implementation is already read-only for copy-mode sources, but it leaves that intent implicit in some places and opens the in-place write handle as `read_write` even though the code only performs positional writes on that handle.

The same module also defines a single `buffer_size` constant at 8192 bytes and reuses it across the streaming core, output-file reader/writer buffers, in-place chunking, and several buffer-boundary tests. This means a buffer-size change is centralized but has knock-on effects in both runtime stack usage and tests.

## Goals / Non-Goals

**Goals:**
- Make file access intent explicit and least-privilege where the current implementation can safely narrow it.
- Prevent directory paths from being treated as ordinary file inputs when opening file-processing handles.
- Raise the shared fixed processing chunk size from 8 KiB to 64 KiB without adding new CLI or runtime configuration.
- Preserve current destination file creation semantics, including overwrite behavior and default permissions governed by Zig create-file defaults plus process `umask`.

**Non-Goals:**
- No new CLI flags, environment variables, or config files for buffer tuning.
- No change to transform semantics, progress reporting, exit-code mapping, or destination naming.
- No change to output-file creation permissions beyond the current default-file behavior.
- No locking, mmap, temp-file rewrite strategy, or broader filesystem hardening beyond open options already used here.

## Decisions

### Make source opens explicit read-only

For copy/output mode and the in-place read handle, use `.mode = .read_only` explicitly rather than relying on the `OpenFileOptions` default. This does not change behavior, but it makes the intended access level obvious in code review and prevents later edits from assuming the empty options struct carries additional meaning.

Alternative considered: keep `.{} ` for read-only opens. Rejected because the code is discussing access narrowing directly, so explicit intent is worth the tiny verbosity cost.

### Narrow the in-place write handle to write-only

Change the second handle in `processInPlaceNoReport` from `.read_write` to `.write_only`. The implementation uses `read_file` for all reads and `write_file` only for `writePositionalAll`, so read access on the write handle is unnecessary.

Alternative considered: keep `read_write` for flexibility. Rejected because there is no current operation that needs read access on that handle, and least-privilege is a direct goal of this change.

### Set `allow_directory = false` on processing file opens

Use `allow_directory = false` on the source and in-place open calls so directory arguments fail through the file-open path rather than permitting directory opens. This expresses the program's intent more precisely: these paths are for regular file processing, not directory handles.

Alternative considered: rely on later read/write failures. Rejected because the open API already exposes this intent, and expressing it early gives cleaner behavior and fewer surprising intermediate states.

### Keep destination create permissions at defaults

Do not set explicit destination permissions such as `0o600`. `createFile` currently uses Zig's `Permissions.default_file`, which maps to standard platform defaults and `umask` behavior. Narrowing access *mode* is an implementation cleanup; narrowing created-file *permissions* would be a user-visible policy change.

Alternative considered: force private outputs via `0o600`. Rejected because it changes current Unix expectations, may break shared-group workflows, and was not requested.

### Increase the shared fixed buffer size to 64 KiB

Update `buffer_size` from 8192 to `64 * 1024` and keep it compile-time fixed. This should reduce syscall frequency for larger files and pipe usage while preserving bounded-memory streaming behavior and avoiding the complexity of a configurable tuning surface.

Alternative considered: make buffer size configurable. Rejected because it adds new interface and test surface without evidence that multiple tunings are needed.

Alternative considered: leave 8 KiB in place. Rejected because the change is centralized, low-risk, and aligned with a simpler performance-oriented default.

## Risks / Trade-offs

- Increased stack usage from larger fixed buffers -> Keep the change scoped to the single shared constant and update tests that assume the old boundary.
- `allow_directory = false` may surface directory inputs as earlier open failures rather than later I/O failures -> Acceptable because the tool is file-oriented and should reject directory paths cleanly.
- Explicit access modes add minor verbosity -> Acceptable because intent clarity is the main reason for the change.
- 64 KiB is a fixed default rather than benchmark-driven tuning -> Acceptable for now because it avoids config complexity while remaining a conventional chunk size.

## Migration Plan

No migration required. The change is internal to file-opening strategy and fixed chunk sizing, with no CLI or artifact format changes.

## Open Questions

- None at proposal time.
