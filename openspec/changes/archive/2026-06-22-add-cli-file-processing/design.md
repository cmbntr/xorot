## Context

`src/main.zig` currently has a narrow entrypoint: it builds stdin/stdout `std.Io` adapters, calls `xorot(reader, writer)`, and flushes stdout. The transform itself is streaming and stateful only through a one-byte index initialized to `0b10101010`, so it is suitable for both filter mode and file mode as long as chunk boundaries preserve the running index.

This change adds CLI and file-system behavior around the existing transform without changing the transform algorithm. The implementation must remain compatible with Zig 0.16.0 APIs already used by the project, including `std.process.Init`, `std.Io.File`, and the newer `std.Io.Reader`/`Writer` interfaces.

## Goals / Non-Goals

**Goals:**

- Preserve no-argument stdin/stdout filter behavior exactly.
- Use a unified internal reader/writer processing core for pipe, output-file, and in-place modes.
- Add Unix-like option parsing for `-i`, `-f`, `---force`, and `--`.
- Treat unknown flags before `--` as errors with exit code `9`.
- Process one or more path arguments in output-file mode or in-place mode.
- In output-file mode, preallocate the destination file size early and return exit code `3` if that disk allocation/preallocation fails.
- Process multiple source files sequentially in CLI order, performing destination preallocation just before each corresponding file is transformed.
- In output-file mode, protect existing destination files unless force is enabled.
- In in-place mode, rewrite the same file directly using chunked read/seek/write, not a temp file and not mmap.
- Emit exactly one `src=<source>,dst=<destination>,cnt=<count>` line on stderr per processing operation, after that operation succeeds or fails.
- In pipe mode, emit `src=-,dst=-,cnt=<count>` after stdin/stdout processing.
- Keep `cnt` conservative and meaningful: bytes fully transformed and successfully written before success or failure.
- Map specified failure categories to stable process exit codes.

**Non-Goals:**

- No recursive directory traversal or glob expansion inside `xorot`.
- No temp-file/rename safety layer for in-place mode; the user explicitly wants true in-place mutation.
- No mmap implementation; chunked in-place rewrite avoids mmap out-of-memory and cross-platform complexity.
- No full-file heap allocation in any file-processing mode; file data is processed with fixed-size buffers.
- No new external dependencies.
- No filename escaping in stderr output beyond printing the exact argument bytes as Zig can write them.

## Decisions

### Use one reader/writer processing core

The transform should be implemented through one internal processing core that accepts a reader, a writer, and fixed-size buffers, then returns `cnt`. Pipe mode supplies stdin/stdout, output-file mode supplies source/destination files, and in-place mode supplies separate read/write streams for the same path.

For in-place mode, prefer two independently opened handles for the same file: one read handle and one write handle opened without truncation. Zig 0.16 `std.Io.File.Reader` and `Writer` default to positional I/O with separate logical offsets, but separate handles avoid shared-offset hazards if an implementation falls back to streaming behavior.

The existing `xorot(reader, writer)` behavior should be preserved through this shared core because it is already tested for empty input, known vectors, buffer boundaries, index wraparound, and fuzz-style generated data.

Alternative considered: maintain separate implementations for pipe, output-file, and in-place paths. That would duplicate logic and risk diverging transform, counting, and reporting behavior.

### Add a buffer transform primitive for counted file operations

File modes need exact progress accounting and fixed-size buffers. Add or refactor toward a small primitive that transforms a mutable byte slice while updating the running `idx`. This lets output-file and in-place paths count only chunks that were fully written.

Alternative considered: make `xorot` return a byte count. That helps streaming output mode, but in-place mode still needs direct chunk mutation and conservative write accounting.

### Parse arguments before opening files

The CLI should first classify arguments into mode and filenames:

- No path arguments means filter mode.
- `-i` enables in-place mode.
- `-f` and `---force` enable overwrite in output-file mode and are accepted but irrelevant in in-place mode.
- `--` ends option parsing; every following argument is a filename.
- Any other `-...` argument before `--` exits with code `9`.

Alternative considered: treat unknown dash-prefixed arguments as filenames. That conflicts with Unix-like tool expectations and the explicit decision to support `--`.

### Use generated destination names only in output-file mode

For each source path in output-file mode:

- If the source ends with `.xorot`, destination is the source without that suffix.
- Otherwise, destination is source plus `.xorot`.

In in-place mode, destination is exactly the source path.

Alternative considered: always append `.xorot`. That breaks decode-style usage where `file.xorot` should produce `file`.

### Create output files with exclusive mode unless forced

Without force, destination creation should fail if the target already exists and map to exit code `2`. With `-f` or `---force`, the destination may be truncated/overwritten.

Alternative considered: pre-check existence before creating. Exclusive creation is preferable because it avoids a time-of-check/time-of-use race.

### Output-file mode preallocates destination disk space early

Output-file mode should stat the source, create/open the destination according to force/exclusive rules, and preallocate or set the destination file length to the required source size before streaming transformation begins. If this early destination disk allocation/preallocation fails, the program exits with code `3`.

For multiple source files, this preallocation is per-file and just-in-time: process the first source through completion before preallocating the second source's destination. The program must not preallocate destination space for all command-line files upfront.

After successful preallocation, output-file mode should transform data chunk by chunk using a fixed-size buffer. It must not allocate memory proportional to source file size.

Alternative considered: allocate a full-size heap buffer before transformation. That was rejected because the intended requirement is early disk allocation for the destination file, not heap allocation, and file processing should remain bounded-memory.

### In-place mode uses chunked true in-place rewrite

In-place mode should open the source read-write, read a fixed-size chunk, transform it in memory, seek back to the chunk start, write the chunk, then advance the count only after the full chunk write succeeds.

This is intentionally true in-place: no destination path, no temp file, no rename, no full-file allocation. It supports large files and avoids mmap-specific out-of-memory behavior.

Alternative considered: mmap. mmap is direct and elegant on POSIX, but it introduces platform/API complexity, zero-length special cases, SIGBUS risk if the file is truncated concurrently, and mmap `OutOfMemory` behavior.

Alternative considered: temp file plus rename. That gives better crash safety but violates the user's clarified requirement for true in-place mutation.

### `cnt` means bytes definitely completed

For success, `cnt` equals the source file size. For failure, `cnt` equals bytes fully transformed and successfully written before the failing operation. If a write API reports an error during a chunk write, do not include that chunk in `cnt` unless the implementation can prove the full chunk was written.

The stderr progress/result line is per processing operation, not per chunk. Chunked processing updates an internal count while processing, then emits one final line using the final conservative count. Pipe mode reports `src=-,dst=-,cnt=<count>`.

Special care is required for the final chunk and operation finalization. The implementation must flush the writer, handle flush/close/final sizing errors, and only report success/count semantics that are consistent with bytes definitely transformed and written. A final short chunk must not leave stale buffered bytes or accidentally write data from a previous full chunk.

Alternative considered: count bytes read or transformed. That can over-report when a later write/flush fails.

### Exit-code mapping is centralized

Implementation should convert internal errors into the requested process exit codes near the CLI/file orchestration boundary:

- `1` for source open/read failures such as not found, permissions, or read failure.
- `2` for destination already exists when force is disabled.
- `3` for destination disk allocation/preallocation failure required by output-file mode.
- `9` for unknown flags and other I/O failures, including destination open/write/flush/seek failures.

Alternative considered: return Zig errors from `main`. That would not provide the required stable numeric exits.

### Multi-file processing is ordered and sequential

When multiple source files are provided, process them exactly in argument order. Each file's open, destination selection, destination preallocation if applicable, transformation, stderr result line, and cleanup happen before moving to the next file.

Alternative considered: pre-scan or preallocate all destination files before transforming any source. That was rejected because disk allocation should happen only immediately before the corresponding source file is processed.

## Risks / Trade-offs

- True in-place mode can leave a partially transformed file if the process crashes or a write fails midway -> Mitigation: document by design, use conservative `cnt`, and never claim bytes from a failed chunk.
- Concurrent modification can produce undefined user-level results -> Mitigation: no locking is specified; keep behavior simple and avoid adding advisory lock semantics without a requirement.
- Destination naming can produce an empty path for a source named exactly `.xorot` -> Mitigation: treat destination creation failure as an I/O failure unless implementation chooses a stricter parse-time validation.
- Destination disk preallocation may not be supported uniformly by every filesystem/API -> Mitigation: use the best available Zig file sizing/preallocation primitive for Zig 0.16.0 and map failure to exit `3` when it represents inability to reserve the required destination size before streaming.
- Buffered writer abstractions may hide exact partial-write counts -> Mitigation: count only after successful full writes/flushes, and prefer direct write-all boundaries where exactness matters.
