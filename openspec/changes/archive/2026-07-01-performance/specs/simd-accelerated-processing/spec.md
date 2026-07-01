## ADDED Requirements

### Requirement: Core byte transformation uses portable SIMD for full vector-width chunks
The implementation SHALL process full vector-width chunks in the core byte transformation path using a portable SIMD strategy that is compatible with the project's supported release targets.

#### Scenario: Full chunks use the SIMD path
- **WHEN** the core transform processes an input slice containing at least one full vector-width chunk
- **THEN** it processes each full chunk with the portable SIMD transform logic before handling any remaining tail bytes

#### Scenario: SIMD width remains compatible with shipped targets
- **WHEN** release artifacts are built for the targets defined by repository release tooling
- **THEN** the chosen vector width remains compatible with those targets without requiring runtime CPU feature detection

### Requirement: SIMD processing preserves transform semantics
The SIMD fast path SHALL produce byte-for-byte identical output to the scalar transform for all input bytes and rolling XOR index states.

#### Scenario: Mixed mapped and unmapped bytes remain identical
- **WHEN** the SIMD path processes bytes spanning alphabetic ROT ranges, numeric ROT ranges, and bytes outside those mapped ranges
- **THEN** the produced output matches the scalar transform exactly for every byte in order

#### Scenario: Rolling XOR index remains contiguous across vector chunks
- **WHEN** SIMD processing advances the rolling XOR index across one or more full vector-width chunks
- **THEN** each byte uses the same XOR index value it would have used in the scalar transform
- **AND** the next processed byte after each chunk continues from the correct subsequent index value

### Requirement: Non-vector tails preserve current behavior
The implementation SHALL continue to correctly process tail bytes that do not fill a complete SIMD chunk.

#### Scenario: Tail bytes fall back without semantic change
- **WHEN** the input slice length is not an exact multiple of the vector width
- **THEN** the remaining tail bytes are processed with behavior identical to the pre-existing scalar transform

#### Scenario: Short inputs remain fully supported
- **WHEN** the input slice is shorter than one full vector-width chunk
- **THEN** the transform still completes successfully and produces the same output as the scalar transform
