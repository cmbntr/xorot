## Context

`xorot` currently performs its byte transformation in a scalar loop inside `transformSlice`, even though the repository's release targets all have a natural 128-bit SIMD path available through Zig portable vectors. The hot path is small and well isolated, existing tests already cover transform correctness and wraparound behavior, and the change must preserve byte-for-byte compatibility across stream, output-file, and in-place modes.

## Goals / Non-Goals

**Goals:**
- Speed up the transform hot path with a portable SIMD implementation that works across the existing release targets.
- Preserve existing output bytes, rolling XOR index semantics, fixed chunk size, and CLI/file-mode behavior.
- Keep the implementation small enough to review and maintain in `src/main.zig`.
- Extend automated tests so SIMD chunk processing and scalar fallback remain behaviorally locked to current semantics.

**Non-Goals:**
- Introducing target-specific runtime dispatch such as AVX2 detection.
- Changing buffer sizes, I/O strategy, file layout, or CLI semantics.
- Adding external dependencies, benchmark harnesses, or architecture-specific intrinsics.

## Decisions

### Use a single portable 16-lane vector path
The implementation will use `@Vector(16, u8)` for the bulk transform loop. This matches the natural 128-bit SIMD width across the current release matrix better than a 32-lane vector, which would rely on splitting on non-AVX2 targets. A 16-lane path keeps the code portable across `x86_64-*`, `aarch64-*`, and `wasm32-wasi-none` without target-specific branching.

Alternative considered: `@Vector(32, u8)` for wider x64 throughput. Rejected because the generic release targets in `Taskfile.yml` do not guarantee AVX2, so the wider type would not map naturally across all shipped artifacts.

### Implement `rot` as branchless vector compare/select logic
The SIMD fast path will introduce a vectorized equivalent of `rot` using range comparisons and `@select` instead of a scalar `switch`. This preserves exact semantics while removing per-byte branch costs in the hot path.

Alternative considered: a 256-byte lookup table. Rejected as the primary strategy because it helps scalar code more than the vector path and adds an extra indirection without simplifying the SIMD implementation.

### Keep scalar code for tails and compatibility
The vector loop will handle full 16-byte chunks, and the remaining tail bytes will continue through the existing scalar transform logic. This keeps the fast path simple while preserving correctness for short inputs and non-multiple-of-16 buffer slices.

Alternative considered: fully replacing scalar logic, including tails, with more complex masked vector handling. Rejected because the extra complexity is not justified for short remainders.

### Preserve current public and internal processing structure
`processCore`, `processInPlaceNoReport`, and the existing reader/writer chunking structure will remain unchanged. The optimization stays localized to `transformSlice` and new helper functions near it.

Alternative considered: restructuring the processing core around architecture-specific workers. Rejected because the change is performance-focused, not architectural.

## Risks / Trade-offs

- [Vector code is easier to get subtly wrong than scalar code] → Mitigation: keep the transform expressed as a direct vector equivalent of current scalar operations and extend tests around chunk boundaries, wraparound, and mixed mapped/unmapped bytes.
- [Performance gains may be limited by I/O for some workloads] → Mitigation: keep the implementation minimal so the optimization cost stays low even if end-to-end wins vary by workload.
- [Portable vectors may lower differently across targets] → Mitigation: choose a 16-lane shape that aligns with the common baseline width of the release matrix.
- [Extra helper functions can reduce readability] → Mitigation: keep helpers local, narrowly scoped, and named directly after the transform steps (`rotVec`, `transformVec`).

## Migration Plan

No data migration or rollout sequencing is required. The change ships as an internal implementation update with behavior-preserving tests. Rollback is straightforward: revert the SIMD helpers and restore the prior scalar-only `transformSlice` loop if regressions are discovered.

## Open Questions

None for the proposal phase. Runtime AVX2 dispatch and benchmarking can be revisited later if the portable 16-lane path is not sufficient.
