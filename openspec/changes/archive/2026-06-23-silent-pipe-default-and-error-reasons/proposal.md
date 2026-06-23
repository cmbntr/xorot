## Why

`xorot` already accepts `-s`, but the main OpenSpec contract does not describe it and still requires pipe mode to emit a stderr progress line by default. That mismatch leaves the current CLI behavior under-specified and blocks a cleaner default for stdin/stdout filter usage.

## What Changes

- Document `-s` as a supported CLI option that suppresses progress/result stderr lines.
- Change no-argument pipe mode so it is silent by default instead of emitting a progress line on stderr.
- Keep file-processing modes progress-reporting by default unless `-s` is provided.
- Require every non-zero exit to emit a stable stderr reason line in the form `code=<n>,reason=<stable-reason>`.
- Define stable reason strings for the existing exit-code mapping and require file-operation failures to emit the progress line before the reason line.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `cli-file-processing`: update option parsing, pipe-mode reporting defaults, and non-zero-exit stderr reporting requirements.

## Impact

- Affects `openspec/specs/cli-file-processing/spec.md`.
- Affects `src/main.zig` CLI/reporting behavior, related tests, and the outstanding CLI documentation TODO sections in `README.md`.
- Does not add dependencies or change the core transform algorithm.
