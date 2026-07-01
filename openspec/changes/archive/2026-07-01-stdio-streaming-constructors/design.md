## Context

`xorot` already shares its main transform loop through `processCore` for pipe mode and output-file mode, while in-place mode uses a separate positional loop. In pipe mode, `main` currently constructs stdin/stdout adapters with `std.Io.File.stdin().reader(...)` and `std.Io.File.stdout().writer(...)`, which default to positional-first behavior before falling back to streaming when the underlying handle is unseekable. For stdin/stdout pipes, that fallback is unnecessary work. The requested change is intentionally narrow: improve this startup path without altering chunk size, CLI semantics, output bytes, or the existing shared `processCore` structure.

## Goals / Non-Goals

**Goals:**
- Use streaming stdio constructors for pipe mode so stdin/stdout avoid positional fallback work on stream-like handles.
- Preserve the existing common `processCore` path as the central transform loop for pipe and output-file processing.
- Keep 64 KiB chunking and all current observable CLI behavior unchanged across supported platforms.
- Capture a simple performance baseline before the code change and measured results after the change in `perf-before.md` and `perf-after.md` beside the change artifacts.

**Non-Goals:**
- Reworking output-file or in-place IO structure.
- Changing buffer sizes, allocation strategy, file layout, or error mapping.
- Introducing target-specific IO APIs or new dependencies.
- Guaranteeing a material end-to-end throughput improvement; the expected gain is small and startup-oriented.

## Decisions

### Use `readerStreaming` and `writerStreaming` only for pipe-mode stdio
Pipe mode will construct stdin and stdout adapters with the streaming-specific stdlib APIs. This keeps the change localized to the known stream-oriented handles and avoids unnecessary positional-read/positional-write fallback attempts.

Alternative considered: changing all file-mode readers and writers to streaming constructors. Rejected because regular file paths already work well with positional-capable adapters, and the requested cleanup is specifically about stdio pipe handling.

### Preserve `processCore` as the shared processing loop
The implementation will keep `processCore` unchanged as the common reader/writer-driven transform loop. Pipe mode will continue to call it directly, and output-file mode will keep using it as well.

Alternative considered: splitting pipe mode into a custom streaming loop. Rejected because it duplicates core logic, increases maintenance cost, and conflicts with the explicit decision to preserve the common processing core.

### Record performance evidence as sibling change artifacts
Implementation should gather a before/after perf snapshot and store it in `perf-before.md` and `perf-after.md` within the change directory. The notes can remain lightweight, but they should record command shape, environment summary, and observed timing/throughput so the change has concrete evidence.

Alternative considered: relying only on reasoning without recorded measurements. Rejected because the expected gain is small enough that measured evidence is more useful than intuition.

## Risks / Trade-offs

- [Measured gain may be negligible] → Mitigation: explicitly record before/after results so the change can be judged on evidence.
- [Tests may not exercise the streaming-constructor distinction directly] → Mitigation: keep behavior-preserving tests green and add or adjust targeted coverage around pipe-mode construction if needed during implementation.
- [Change could accidentally expand beyond pipe mode] → Mitigation: scope edits to stdin/stdout construction and preserve `processCore` rather than refactoring other IO paths.

## Migration Plan

No migration or rollout steps are required. The implementation can be applied directly, validated with the existing test suite plus perf notes, and rolled back by restoring the previous stdio constructor calls if needed.

## Open Questions

None for proposal scope.
