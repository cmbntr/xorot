## Why

The current byte transformation path in `src/main.zig` is entirely scalar, so CPU time scales linearly with per-byte branching even on targets that support efficient SIMD execution. A focused performance change is useful now because the transform is already covered by correctness tests, the target matrix includes multiple SIMD-capable platforms, and the main hot path is isolated to a small set of functions.

## What Changes

- Add a portable SIMD implementation for the core byte transformation path used by stream, output-file, and in-place processing.
- Preserve current byte-for-byte output semantics, rolling XOR index behavior, and chunk-count semantics across all processing modes.
- Keep a scalar fallback for tails and targets where the vector path is not applicable.
- Add targeted tests for SIMD chunk boundaries and wraparound behavior so optimization changes remain behaviorally safe.

## Capabilities

### New Capabilities
- `simd-accelerated-processing`: Defines the requirement for a portable SIMD fast path in the byte transformation core while preserving current transform semantics and fallback behavior across supported targets.

### Modified Capabilities
- `xorot-test-coverage`: Extend coverage to explicitly protect SIMD chunk-boundary and fallback equivalence behavior.

## Impact

- Affected code: `src/main.zig` transform hot path and related tests.
- Affected behavior: no intended user-visible CLI or file-format changes; output must remain byte-for-byte compatible.
- Affected targets: `x86_64-*`, `aarch64-*`, and `wasm32-wasi-none` builds, with portable-vector implementation chosen to fit the existing release matrix.
