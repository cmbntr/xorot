## MODIFIED Requirements

### Requirement: Release build task remains functional
The project SHALL keep `task build` as the release entry point and SHALL produce packaged release outputs for each supported target in the configured target matrix for the current execution environment.

#### Scenario: Release task completes for supported targets locally
- **WHEN** a developer runs `task build` outside GitHub Actions
- **THEN** each configured local supported target completes `zig build install`
- **AND** each successful target output is packaged into the expected `release/` zip artifact

#### Scenario: Release task completes for supported targets in GitHub Actions
- **WHEN** GitHub Actions runs `task build`
- **THEN** each configured GitHub Actions supported target completes `zig build install`
- **AND** each successful target output is packaged into the expected `release/` zip artifact
- **AND** the GitHub Actions target set excludes macOS targets

### Requirement: Target matrix uses Zig 0.16-compatible target names
The release target list SHALL use target names accepted by Zig 0.16 for every target kept in the supported release matrix for the current execution environment.

#### Scenario: Taskfile target names are valid locally
- **WHEN** `task build` iterates over the configured local targets
- **THEN** Zig 0.16 recognizes each target string as valid input to `-Dtarget`

#### Scenario: Taskfile target names are valid in GitHub Actions
- **WHEN** `task build` iterates over the configured GitHub Actions targets
- **THEN** Zig 0.16 recognizes each target string as valid input to `-Dtarget`
