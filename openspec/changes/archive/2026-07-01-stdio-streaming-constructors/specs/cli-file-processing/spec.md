## MODIFIED Requirements

### Requirement: No-argument filter mode
The program SHALL preserve stdin/stdout data transformation behavior when invoked with no command-line parameters other than the executable name and SHALL be silent on stderr by default in pipe mode. Pipe-mode stdio construction SHALL use streaming-compatible reader and writer adapters while preserving the existing transform output and count semantics.

#### Scenario: No parameters use filter mode
- **WHEN** the program is invoked with no file or option arguments
- **THEN** it reads from stdin, writes the transformed bytes to stdout, and does not require file-system source or destination paths

#### Scenario: No parameters do not report pipe count by default
- **WHEN** the program is invoked with no file or option arguments
- **THEN** it does not emit a `src=-,dst=-,cnt=<count>` stderr line after stdin/stdout processing unless a future explicit opt-in reporting feature is added

#### Scenario: Pipe mode uses streaming stdio adapters
- **WHEN** no-argument pipe mode constructs stdin and stdout processing adapters
- **THEN** it uses streaming-oriented stdio reader and writer construction rather than positional-first construction
- **AND** it preserves the existing transformed byte stream and exit semantics

### Requirement: Unified processing core
The program SHALL use a unified reader/writer processing core for pipe, output-file, and in-place modes, with a fixed chunk size of 64 KiB. Pipe mode and output-file mode SHALL continue to share the common `processCore` transform loop, while in-place mode may keep its mode-specific positional read/write loop so long as transform bytes and count semantics remain aligned.

#### Scenario: Pipe mode uses unified processing
- **WHEN** no-argument pipe mode processes stdin to stdout
- **THEN** processing uses the same transform, fixed-size 64 KiB chunking, and count semantics as file modes

#### Scenario: File modes use unified processing
- **WHEN** output-file or in-place mode processes a file
- **THEN** processing uses the same transform, fixed-size 64 KiB chunking, and count semantics as pipe mode

#### Scenario: Pipe and output-file modes preserve the shared core
- **WHEN** implementation details for pipe-mode stdio construction change
- **THEN** pipe mode still invokes the shared `processCore` reader/writer loop
- **AND** output-file mode continues to use that same shared core

### Requirement: Performance evidence is recorded for streaming-stdio changes
The implementation process for changes to pipe-mode stdio construction SHALL record a baseline and post-change performance note as sibling files in the active change directory.

#### Scenario: Baseline performance note exists before implementation evaluation
- **WHEN** implementation work for the streaming-stdio change begins
- **THEN** the change directory contains a `perf-before.md` file describing the baseline command shape and observed result summary

#### Scenario: Post-change performance note exists after implementation evaluation
- **WHEN** implementation work for the streaming-stdio change is validated
- **THEN** the change directory contains a `perf-after.md` file describing the post-change command shape and observed result summary
