## ADDED Requirements

### Requirement: File processing uses least-privilege open modes
The program SHALL request only the file access modes needed for each file-processing handle.

#### Scenario: Copy-mode source opens read-only
- **WHEN** output-file mode opens a source path for reading and statting before transformation
- **THEN** it requests read-only access for that source handle

#### Scenario: In-place mode separates read and write privileges
- **WHEN** in-place mode opens two handles for the same path
- **THEN** the read handle requests read-only access
- **AND** the write handle requests write-only access

#### Scenario: File-processing opens reject directories
- **WHEN** a file-processing path is opened for source or in-place processing
- **THEN** the open request rejects directory targets rather than intentionally allowing directory handles

### Requirement: Output-file processing uses 64 KiB fixed buffers
The program SHALL use fixed-size 64 KiB processing buffers in output-file mode and SHALL not allocate heap memory proportional to the source file size.

#### Scenario: Output-file processing keeps a fixed buffer budget
- **WHEN** output-file mode processes a source file
- **THEN** it uses fixed-size 64 KiB processing buffers
- **AND** it does not allocate heap memory proportional to the source file size

## MODIFIED Requirements

### Requirement: Unified processing core
The program SHALL use a unified reader/writer processing core for pipe, output-file, and in-place modes, with a fixed chunk size of 64 KiB.

#### Scenario: Pipe mode uses unified processing
- **WHEN** no-argument pipe mode processes stdin to stdout
- **THEN** processing uses the same transform, fixed-size 64 KiB chunking, and count semantics as file modes

#### Scenario: File modes use unified processing
- **WHEN** output-file or in-place mode processes a file
- **THEN** processing uses the same transform, fixed-size 64 KiB chunking, and count semantics as pipe mode
