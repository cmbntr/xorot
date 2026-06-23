## MODIFIED Requirements

### Requirement: No-argument filter mode
The program SHALL preserve stdin/stdout data transformation behavior when invoked with no command-line parameters other than the executable name and SHALL be silent on stderr by default in pipe mode.

#### Scenario: No parameters use filter mode
- **WHEN** the program is invoked with no file or option arguments
- **THEN** it reads from stdin, writes the transformed bytes to stdout, and does not require file-system source or destination paths

#### Scenario: No parameters do not report pipe count by default
- **WHEN** the program is invoked with no file or option arguments
- **THEN** it does not emit a `src=-,dst=-,cnt=<count>` stderr line after stdin/stdout processing unless a future explicit opt-in reporting feature is added

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

#### Scenario: Silent suppresses progress reporting
- **WHEN** the argument list contains `-s`
- **THEN** the program suppresses progress/result stderr lines for pipe and file processing operations

### Requirement: File progress reporting
The program SHALL emit exactly one stderr progress/result line per file-processing operation in the form `src=<source>,dst=<destination>,cnt=<count>` unless `-s` is enabled.

#### Scenario: Successful file operation reports full count
- **WHEN** a file operation succeeds and `-s` is not enabled
- **THEN** the emitted stderr line reports `cnt` equal to the source file size

#### Scenario: Chunked in-place operation reports once
- **WHEN** in-place mode processes a source file using multiple chunks and `-s` is not enabled
- **THEN** the program emits one stderr progress/result line for that source file rather than one line per chunk

#### Scenario: Pipe operation does not report by default
- **WHEN** pipe mode processes stdin to stdout without `-s`
- **THEN** the program does not emit a stderr progress/result line for the pipe operation

#### Scenario: Failed file operation reports conservative count
- **WHEN** a file operation fails after processing begins and `-s` is not enabled
- **THEN** the emitted stderr progress/result line reports `cnt` as the number of bytes fully transformed and successfully written before the failing operation

#### Scenario: Source open failure reports zero count
- **WHEN** a source file cannot be opened before any bytes are processed and `-s` is not enabled
- **THEN** the emitted stderr progress/result line reports `cnt=0`

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
