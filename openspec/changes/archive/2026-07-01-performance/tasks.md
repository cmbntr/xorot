## 1. SIMD Transform Helpers

- [x] 1.1 Add portable 16-lane SIMD constants and helper functions near `transformSlice` in `src/main.zig`
- [x] 1.2 Implement a branchless SIMD `rotVec` equivalent to the existing scalar `rot` semantics
- [x] 1.3 Implement a SIMD chunk transform that applies the rolling XOR index sequence and preserves wraparound behavior

## 2. Integrate The Fast Path

- [x] 2.1 Update `transformSlice` to process full 16-byte chunks with the SIMD path
- [x] 2.2 Preserve scalar processing for tail bytes and short inputs so behavior matches the existing implementation exactly
- [x] 2.3 Keep `processCore`, output-file mode, and in-place mode wiring unchanged apart from using the optimized transform path

## 3. Verification

- [x] 3.1 Add tests that exercise lengths below, equal to, and above the SIMD chunk width
- [x] 3.2 Add or extend tests that verify XOR-index wraparound remains correct when processing across SIMD chunk boundaries
- [x] 3.3 Run `zig build test` and relevant smoke tests to confirm byte-for-byte compatibility after the optimization
