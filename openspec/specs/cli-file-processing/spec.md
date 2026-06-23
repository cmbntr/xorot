# cli-file-processing Specification

## Purpose
TBD - created by archiving change add-cli-file-processing. Update Purpose after archive.
## Requirements
### Requirement: No-argument filter mode
The program SHALL preserve stdin/stdout data transformation behavior when invoked with no command-line parameters other than the executable name and SHALL be silent on stderr by default in pipe mode.

#### Scenario: No parameters use filter mode
- **WHEN** the program is invoked with no file or option arguments
- **THEN** it reads from stdin, writes the transformed bytes to stdout, and does not require file-system source or destination paths

#### Scenario: No parameters do not report pipe count by default
- **WHEN** the program is invoked with no file or option arguments
- **THEN** it does not emit a `src=-,dst=-,cnt=<count>` stderr line after stdin/stdout processing unless a future explicit opt-in reporting feature is added

### Requirement: Unified processing core
The program SHALL use a unified reader/writer processing core for pipe, output-file, and in-place modes, with a fixed chunk size of 64 KiB.

#### Scenario: Pipe mode uses unified processing
- **WHEN** no-argument pipe mode processes stdin to stdout
- **THEN** processing uses the same transform, fixed-size 64 KiB chunking, and count semantics as file modes

#### Scenario: File modes use unified processing
- **WHEN** output-file or in-place mode processes a file
- **THEN** processing uses the same transform, fixed-size 64 KiB chunking, and count semantics as pipe mode

### Requirement: Unix-like option parsing
The program SHALL parse `-i`, `-f`, `---force`, `-s`, and `--` before file processing begins.

#### Scenario: End-of-options marker allows dash-prefixed filenames
- **WHEN** the argument list contains `--` followed by `-named-file`
- **THEN** `-named-file` is treated as a filename and not as an option

#### Scenario: Unknown flag before end-of-options fails
- **WHEN** the argument list contains an unrecognized dash-prefixed argument before `--`
- **THEN** the program exits with code `9`

#### Scenario: Force is accepted in in-place mode
- **WHEN** the argument list contains `-i` and `-f` or `---force`
- **THEN** force is accepted and has no effect on destination naming or overwrite checks because in-place mode uses the source path as destination

### Requirement: Output-file mode destination naming
The program SHALL process `xorot file1 file2 ... fileN` by creating one output file per source file using suffix-based naming.

#### Scenario: Source without xorot suffix appends suffix
- **WHEN** output-file mode processes a source path that does not end with `.xorot`
- **THEN** the destination path is the source path with `.xorot` appended

#### Scenario: Source with xorot suffix strips suffix
- **WHEN** output-file mode processes a source path that ends with `.xorot`
- **THEN** the destination path is the source path with the trailing `.xorot` suffix removed

### Requirement: Output-file overwrite protection
The program SHALL refuse to overwrite existing output files unless force is enabled.

#### Scenario: Destination exists without force
- **WHEN** output-file mode would create a destination path that already exists and force is not enabled
- **THEN** the program exits with code `2`

#### Scenario: Destination exists with force
- **WHEN** output-file mode would create a destination path that already exists and `-f` or `---force` is enabled
- **THEN** the program overwrites the existing destination file

### Requirement: Output-file early destination allocation
The program SHALL allocate or preallocate the required destination file size early in output-file mode and report that failure distinctly.

#### Scenario: Destination allocation is per file
- **WHEN** output-file mode processes multiple source files
- **THEN** the program allocates or preallocates each destination file immediately before processing the corresponding source file rather than allocating or preallocating all destinations upfront

#### Scenario: Required destination allocation fails
- **WHEN** output-file mode cannot allocate or preallocate the required destination file size for a source file
- **THEN** the program exits with code `3`

#### Scenario: Output-file processing uses bounded memory
- **WHEN** output-file mode processes a source file
- **THEN** the program uses fixed-size processing buffers and does not allocate heap memory proportional to the source file size

### Requirement: True in-place mode
The program SHALL process `xorot -i file1 file2 ... fileN` by transforming each source file directly at the same path.

#### Scenario: In-place mode preserves filename
- **WHEN** in-place mode processes a source file
- **THEN** the destination path is identical to the source path

#### Scenario: In-place mode uses chunked same-file rewrite
- **WHEN** in-place mode transforms a file
- **THEN** the program reads chunks from the source file, transforms each chunk, seeks back to the chunk offset, and writes the transformed chunk to the same file without creating a separate output file

### Requirement: File progress reporting
The program SHALL emit exactly one stderr progress/result line per file-processing operation in the form `src=<source>,dst=<destination>,cnt=<count>` unless `-s` is enabled.

#### Scenario: Successful file operation reports full count
- **WHEN** a file operation succeeds
- **THEN** the emitted stderr line reports `cnt` equal to the source file size

#### Scenario: Chunked in-place operation reports once
- **WHEN** in-place mode processes a source file using multiple chunks
- **THEN** the program emits one stderr line for that source file rather than one line per chunk

#### Scenario: Pipe operation does not report by default
- **WHEN** pipe mode processes stdin to stdout
- **THEN** the program does not emit a stderr progress/result line for the pipe operation

#### Scenario: Silent suppresses progress reporting
- **WHEN** the argument list contains `-s`
- **THEN** the program suppresses progress/result stderr lines for pipe and file processing operations

#### Scenario: Failed file operation reports conservative count
- **WHEN** a file operation fails after processing begins
- **THEN** the emitted stderr line reports `cnt` as the number of bytes fully transformed and successfully written before the failing operation

#### Scenario: Source open failure reports zero count
- **WHEN** a source file cannot be opened before any bytes are processed
- **THEN** the emitted stderr line reports `cnt=0`

### Requirement: Ordered multi-file processing
The program SHALL process multiple source file arguments sequentially in the exact order provided on the command line.

#### Scenario: Files are processed in argument order
- **WHEN** the program is invoked with `first second third`
- **THEN** it completes processing or fails `first` before starting `second`, and completes processing or fails `second` before starting `third`

#### Scenario: Failure stops subsequent files
- **WHEN** processing a source file fails
- **THEN** the program exits with the mapped error code without processing later source file arguments

### Requirement: Source-read failures
The program SHALL exit with code `1` when a source file cannot be opened or read due to not found, permissions, or similar source-read failure.

#### Scenario: Source file missing
- **WHEN** file mode processes a source path that does not exist
- **THEN** the program exits with code `1`

#### Scenario: Source file unreadable
- **WHEN** file mode processes a source path that cannot be read due to permissions or read error
- **THEN** the program exits with code `1`

### Requirement: Other I/O failures
The program SHALL exit with code `9` for I/O failures that are not source-read failures, destination-exists failures, or required destination allocation/preallocation failures.

#### Scenario: Destination write failure
- **WHEN** a destination write, seek, flush, or close operation fails
- **THEN** the program exits with code `9`

#### Scenario: Unknown flag failure
- **WHEN** option parsing encounters an unknown flag before `--`
- **THEN** the program exits with code `9`

### Requirement: Failure reason reporting
The program SHALL emit exactly one stderr failure reason line for every non-zero exit in the form `code=<n>,reason=<stable-reason>`.

#### Scenario: Source failure reason is stable
- **WHEN** the program exits with code `1`
- **THEN** it emits `code=1,reason=source-read-failure`

#### Scenario: Destination exists reason is stable
- **WHEN** the program exits with code `2`
- **THEN** it emits `code=2,reason=destination-exists`

#### Scenario: Allocation failure reason is stable
- **WHEN** the program exits with code `3`
- **THEN** it emits `code=3,reason=destination-allocation-failure`

#### Scenario: Other failure reason is stable
- **WHEN** the program exits with code `9`
- **THEN** it emits `code=9,reason=other-io-or-usage-failure`

#### Scenario: Silent does not suppress failure reason
- **WHEN** the program exits non-zero and `-s` is enabled
- **THEN** it still emits the stderr failure reason line

#### Scenario: File failure reports progress before reason
- **WHEN** a file-processing operation exits non-zero after determining source and destination context and `-s` is not enabled
- **THEN** the program emits the `src=<source>,dst=<destination>,cnt=<count>` stderr progress/result line before the `code=<n>,reason=<stable-reason>` stderr failure reason line

#### Scenario: Parse failure reports only reason
- **WHEN** option parsing exits non-zero before any processing operation begins
- **THEN** the program emits only the `code=<n>,reason=<stable-reason>` stderr failure reason line

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
