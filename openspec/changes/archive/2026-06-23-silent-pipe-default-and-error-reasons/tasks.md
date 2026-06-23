## 1. Update CLI stderr behavior

- [x] 1.1 Adjust `src/main.zig` progress-reporting flow so no-argument pipe mode is silent by default while file modes still emit `src=...,dst=...,cnt=...` unless `-s` is enabled.
- [x] 1.2 Add a centralized helper in `src/main.zig` that maps non-zero `ExitCode` values to stable reason strings and emits `code=<n>,reason=<stable-reason>` to stderr before exiting.
- [x] 1.3 Route parse failures and file-operation failures through the centralized exit helper while preserving file-failure ordering of progress line first and reason line second.

## 2. Update tests and documentation

- [x] 2.1 Update Zig tests in `src/main.zig` to cover `-s` parsing, pipe-mode default silence, exact failure reason strings, and failure-report ordering.
- [x] 2.2 Add or update CLI-level verification so a non-zero exit always emits `code=<n>,reason=<stable-reason>`, including when `-s` is supplied.
- [x] 2.3 Replace the `README.md` usage TODO sections for flags, pipe mode, file copy mode, and file inplace mode with documentation that matches the implemented CLI stderr and reporting contract.

## 3. Validate the change

- [x] 3.1 Run `zig build test` and confirm all Zig tests pass.
- [x] 3.2 Run the relevant smoke checks for stdin/stdout behavior and stderr reporting to verify the new defaults do not change the core transform output.
