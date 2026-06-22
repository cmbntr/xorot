## 1. Core Test Harness

- [x] 1.1 Add a minimal Zig test harness for exercising `rot` and `xorot` directly from `src/main.zig` without changing runtime behavior.
- [x] 1.2 Add a compact reference transform helper for computing expected `xorot` output inside tests.

## 2. Deterministic Coverage

- [x] 2.1 Add unit tests for `rot` covering uppercase, lowercase, numeric, and passthrough boundary bytes.
- [x] 2.2 Add deterministic `xorot` tests for empty input and at least one fixed known input/output vector.
- [x] 2.3 Add deterministic `xorot` tests covering buffer-boundary chunking and XOR index wraparound behavior.

## 3. Randomized And Fuzz-Style Coverage

- [x] 3.1 Add deterministic property-oriented tests that generate seeded random binary inputs and verify invariants such as length preservation and equality with the reference transform.
- [x] 3.2 Add a fuzz-oriented stress path using supported Zig tooling or repository build configuration to run many generated-input iterations without affecting production behavior.

## 4. Workflow Verification

- [x] 4.1 Update the build/test workflow as needed so developers can run the default test suite and the fuzz-oriented path with documented repository commands.
- [x] 4.2 Run the relevant Zig test commands and confirm the new deterministic, property-oriented, and fuzz-style coverage passes.
