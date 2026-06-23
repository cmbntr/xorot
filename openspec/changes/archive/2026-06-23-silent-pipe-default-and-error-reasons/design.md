## Context

`xorot` recently gained CLI file-processing behavior, stderr progress reporting, and stable numeric exit codes. The current implementation already parses `-s`, but the main spec does not mention that flag and still requires no-argument pipe mode to emit a progress line on stderr. We also want failures to communicate their exit classification directly on stderr instead of requiring callers to infer meaning from the numeric exit code alone.

The affected surface area is small and localized to `src/main.zig`, its tests, and the `cli-file-processing` capability spec. The transform algorithm, streaming core, and file-processing exit-code categories stay intact.

## Goals / Non-Goals

**Goals:**

- Align the `cli-file-processing` spec with the existing `-s` flag.
- Make no-argument pipe mode silent by default while keeping file modes progress-reporting by default.
- Define a stable stderr reason line for every non-zero exit using `code=<n>,reason=<stable-reason>`.
- Preserve the existing per-operation progress line for file modes and require failure ordering of progress line first, reason line second.
- Keep failure-reason reporting active even when `-s` suppresses progress lines.

**Non-Goals:**

- No changes to the xorot transform algorithm or buffer semantics.
- No new CLI verbosity flag beyond the existing `-s`.
- No change to the existing numeric exit-code mapping.
- No structured machine-readable format beyond the single-line `code=...,reason=...` stderr record.

## Decisions

### Separate progress suppression from failure classification

`-s` will suppress only progress/result lines of the form `src=<source>,dst=<destination>,cnt=<count>`. It will not suppress failure reason lines. This preserves a quiet success path while ensuring failures always communicate their stable classification to users and scripts.

Alternative considered: make `-s` suppress all stderr output, including failure reasons. Rejected because it would hide required diagnostics and weaken the new stderr contract for non-zero exits.

### Pipe mode is silent by default, file modes remain verbose by default

The implementation should decide progress reporting from execution mode rather than changing the meaning of `Cli.silent`. Pipe mode should not emit a progress line unless a future feature introduces an explicit opt-in reporting flag. File-processing modes should keep the current per-operation progress line unless `-s` is provided.

Alternative considered: add a new positive verbosity flag now. Rejected because the requested behavior can be implemented with a smaller change and without expanding the CLI surface.

### Centralize exit-code-to-reason reporting

The implementation should map `ExitCode` values to stable reason strings in one helper and route all explicit non-zero process exits through that helper. This keeps parse failures and file-operation failures consistent and avoids scattering string literals across error paths.

The stable mapping will be:

- `1` -> `source-read-failure`
- `2` -> `destination-exists`
- `3` -> `destination-allocation-failure`
- `9` -> `other-io-or-usage-failure`

Alternative considered: include the reason inside the existing `src=...,dst=...,cnt=...` line. Rejected because successful operations do not have a failure reason and the file-progress line already has a separate established meaning.

### Preserve failure ordering for file operations

When a file operation fails after a processing attempt has been classified, stderr should emit the per-operation progress line first and the `code=...,reason=...` line second. Parse failures, which have no associated source/destination operation, should emit only the reason line.

Alternative considered: emit only the reason line on failure. Rejected because the existing `cnt` contract remains useful for partial-progress failures and should stay available.

## Risks / Trade-offs

- [Existing users may rely on pipe-mode stderr progress output] -> Mitigation: capture the behavior change explicitly in the spec and change proposal so the silent-by-default shift is intentional and reviewable.
- [Tests that assume all stderr is suppressible by `-s` may need adjustment] -> Mitigation: make the spec explicit that failure reason lines are mandatory even under `-s`.
- [Centralizing exits can accidentally bypass flushing/reporting order] -> Mitigation: keep progress reporting and failure-reason reporting as separate small helpers and test exact output ordering.
