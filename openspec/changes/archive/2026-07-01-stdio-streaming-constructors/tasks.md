## 1. Baseline And Scope

- [x] 1.1 Record a pipe-mode performance baseline in `openspec/changes/stdio-streaming-constructors/perf-before.md`, including command shape, environment summary, and observed result values.
- [x] 1.2 Confirm the implementation scope remains limited to pipe-mode stdio construction while preserving the shared `processCore` path and 64 KiB chunking behavior.

## 2. Implementation

- [x] 2.1 Update pipe mode in `src/main.zig` to construct stdin/stdout adapters with streaming stdio constructors instead of the positional-first defaults.
- [x] 2.2 Preserve the existing `processCore` usage and ensure file modes continue to keep their current semantics and error mapping.

## 3. Validation

- [x] 3.1 Run relevant automated tests for pipe mode and file mode behavior to confirm no CLI or transform regressions.
- [x] 3.2 Record post-change performance results in `openspec/changes/stdio-streaming-constructors/perf-after.md`, using a comparable command shape to the baseline.
