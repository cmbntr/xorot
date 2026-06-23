## Why

`xorot` currently only behaves as a stdin/stdout filter, which makes file workflows require shell redirection and external naming logic. Adding first-class CLI file processing makes the tool usable directly for encode/decode file operations while preserving the existing filter behavior when no arguments are provided.

## What Changes

- Add command-line parsing for filter mode, output-file mode, and true in-place mode.
- Preserve current stdin/stdout filter behavior when no file parameters are provided.
- Use a unified internal processing core for pipe, output-file, and in-place modes based on a reader, writer, fixed-size buffer, running xorot index, and returned byte count.
- Add output-file mode for `xorot file1 file2 ... fileN` using fixed-size processing buffers.
- Process multiple file arguments sequentially in the exact order provided on the command line.
- In output-file mode, derive each destination by stripping a trailing `.xorot` suffix or appending `.xorot` when the suffix is absent.
- In output-file mode, perform early destination disk allocation/preallocation immediately before processing the corresponding source file, not as an upfront reservation for all input files.
- Refuse to overwrite an existing output file unless `-f` or `---force` is passed.
- Add true in-place mode for `xorot -i file1 file2 ... fileN`, rewriting each source file without changing its filename and without using a temp output file.
- Implement file transformations with chunked fixed-size buffers; in-place mode uses read/seek/write over the same file, avoiding full-file allocation and mmap out-of-memory behavior.
- Support `--` as an end-of-options marker; all following arguments are treated as filenames, even if they begin with `-`.
- Treat unknown flags before `--` as usage/argument errors that exit with code `9`.
- Allow `-f`/`---force` with `-i`, but make it irrelevant because in-place mode has no separate destination collision to resolve.
- Emit one stderr progress/result line per processing operation using `src=<source>,dst=<destination>,cnt=<count>`.
- In no-argument pipe mode, emit `src=-,dst=-,cnt=<count>` on stderr after processing stdin to stdout.
- Define `cnt` as bytes fully transformed and successfully written to the destination; on failure it reports bytes definitely completed before the failing operation.
- Add explicit exit-code behavior:
  - `1`: source file cannot be opened/read due not found, permissions, or similar source-read failure.
  - `2`: output target already exists and force was not requested.
  - `3`: required early disk allocation/preallocation of the destination file fails in output-file mode.
  - `9`: unknown flags before `--` and any other I/O failure, including destination write/flush/seek failures.

## Capabilities

### New Capabilities

- `cli-file-processing`: Command-line file processing behavior, including argument parsing, destination naming, in-place rewrite mode, overwrite protection, stderr reporting, and exit-code mapping.

### Modified Capabilities

- None.

## Impact

- Affects `src/main.zig` command-line entrypoint and file I/O flow.
- Preserves the existing `xorot` streaming transform semantics and stdin/stdout no-argument behavior.
- Adds tests for argument parsing, destination naming, file processing success paths, overwrite handling, source-read failures, unknown flags, `--`, force behavior, in-place chunked rewrite, and `cnt` reporting.
- No new external dependencies are expected.
