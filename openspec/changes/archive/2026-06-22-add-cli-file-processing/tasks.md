## 1. CLI Parsing

- [x] 1.1 Add argument parsing around `std.process.Init` args while preserving no-argument stdin/stdout filter mode.
- [x] 1.2 Recognize `-i`, `-f`, `---force`, and `--`; treat all arguments after `--` as filenames.
- [x] 1.3 Exit with code `9` for unknown dash-prefixed flags before `--`.
- [x] 1.4 Add parser tests for no args, output-file mode, in-place mode, force flags, `--`, dash-prefixed filenames after `--`, and unknown flags.

## 2. Transform Refactor

- [x] 2.1 Implement a unified reader/writer processing core shared by pipe, output-file, and in-place modes.
- [x] 2.2 Extract a byte-slice transform primitive that updates the running xorot index across chunks.
- [x] 2.3 Return `cnt` from the shared core as bytes fully transformed and successfully written.
- [x] 2.4 Keep existing stdin/stdout transform output intact while adding pipe stderr reporting as `src=-,dst=-,cnt=<count>`.
- [x] 2.5 Add tests proving refactored chunk handling still matches existing vectors, boundary behavior, index wraparound, generated inputs, and pipe count reporting.

## 3. Output-File Mode

- [x] 3.1 Implement destination naming: strip trailing `.xorot`, otherwise append `.xorot`.
- [x] 3.2 Open/read/stat each source and map source open/read failures to exit code `1`.
- [x] 3.3 Preallocate or set the destination file to the required source size early and map destination disk allocation/preallocation failure to exit code `3`.
- [x] 3.4 Create output files exclusively when force is disabled and map destination-exists failures to exit code `2`.
- [x] 3.5 Overwrite/truncate destination files when `-f` or `---force` is enabled.
- [x] 3.6 Transform output-file data using fixed-size buffers only, with no heap allocation proportional to source file size.
- [x] 3.7 Track `cnt` as bytes fully transformed and successfully written.
- [x] 3.8 Add tests for destination naming, successful output creation, suffix stripping, overwrite refusal, force overwrite, destination allocation-error handling where feasible, bounded-buffer processing, source-read failure, and stderr `cnt` reporting.

## 4. Multi-File Ordering

- [x] 4.1 Process multiple source arguments sequentially in exact CLI order.
- [x] 4.2 Perform output-file destination preallocation just before transforming the corresponding source file, not upfront for all inputs.
- [x] 4.3 Stop at the first failed source file and do not process later source arguments.
- [x] 4.4 Add tests for ordered multi-file processing, per-file just-in-time destination preallocation where feasible, and stop-on-first-failure behavior.

## 5. In-Place Mode

- [x] 5.1 Implement true in-place processing with read-write source open, fixed-size chunk buffer, seek-back, and same-file write.
- [x] 5.2 Prefer separate read and write handles for in-place mode to avoid shared-offset hazards.
- [x] 5.3 Ensure in-place destination is exactly the source path and force flags are accepted but irrelevant.
- [x] 5.4 Count only chunks fully transformed and successfully written; report conservative `cnt` on failures.
- [x] 5.5 Map source open/read failures to exit code `1` and seek/write/flush failures to exit code `9`.
- [x] 5.6 Add tests for in-place success, empty files, multi-chunk files, dash-prefixed filenames after `--`, force-with-in-place behavior, and conservative stderr `cnt` reporting.

## 6. Reporting And Exit Codes

- [x] 6.1 Emit exactly one stderr line per processing operation as `src=<source>,dst=<destination>,cnt=<count>`, including pipe mode and chunked file modes.
- [x] 6.2 Centralize file-mode failure-to-exit-code mapping for codes `1`, `2`, `3`, and `9`.
- [x] 6.3 Ensure processing exits on first failure with the requested code after reporting that attempted file's conservative count.
- [x] 6.4 Handle final chunks, writer flushes, file finalization, and resource close paths without over-reporting `cnt`.
- [x] 6.5 Add integration-style tests or build-run checks covering success and each specified exit code.

## 7. Verification

- [x] 7.1 Run `zig build test`.
- [x] 7.2 Run focused manual `zig build run -- ...` checks for no-argument filter behavior, output-file mode, in-place mode, force overwrite, `--`, ordered multi-file processing, and failure exit codes.
- [x] 7.3 Run `task ai:openspec -- status --change "add-cli-file-processing"` and verify artifacts remain coherent.
