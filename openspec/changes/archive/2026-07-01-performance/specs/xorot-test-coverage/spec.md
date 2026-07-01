## ADDED Requirements

### Requirement: SIMD and scalar paths are covered by equivalent automated tests
The project SHALL include automated tests that verify the SIMD chunk path and scalar fallback path produce identical results for the same logical transform inputs.

#### Scenario: SIMD chunk boundary coverage is explicit
- **WHEN** the automated test suite exercises inputs around the chosen SIMD vector width boundary
- **THEN** the tests verify identical output for lengths below, equal to, and above that boundary

#### Scenario: Scalar fallback remains equivalent after vector chunks
- **WHEN** the automated test suite exercises an input that includes one or more full SIMD chunks followed by a non-empty tail
- **THEN** the tests verify that the tail output matches the reference transform exactly

### Requirement: SIMD-path wraparound behavior is protected by tests
The project SHALL include automated tests that verify rolling XOR index wraparound remains correct when processing spans SIMD chunk boundaries.

#### Scenario: Vectorized processing crosses the wrap point
- **WHEN** the automated test suite exercises an input long enough for the XOR index to wrap while full SIMD chunks are processed
- **THEN** the output matches the reference transform across the wrap point exactly

#### Scenario: Repeated runs stay deterministic after optimization
- **WHEN** the default automated test suite is run repeatedly after the SIMD optimization is introduced
- **THEN** the SIMD-related tests produce deterministic pass/fail results in the same source state
