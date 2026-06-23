## 1. Tighten file-open intent

- [x] 1.1 Make copy/output-mode source opens explicit with `.mode = .read_only` and `allow_directory = false`.
- [x] 1.2 Make the in-place read handle explicit `read_only` with `allow_directory = false`.
- [x] 1.3 Narrow the in-place write handle to `write_only` and set `allow_directory = false`.
- [x] 1.4 Preserve current destination create behavior, including default create permissions and existing overwrite/error mapping.

## 2. Raise fixed buffer size

- [x] 2.1 Change the shared `buffer_size` constant from 8 KiB to 64 KiB.
- [x] 2.2 Update buffer-boundary and multi-chunk tests to derive expectations from `buffer_size` rather than hardcoded `8192` assumptions.
- [x] 2.3 Review stack-buffer call sites to ensure the larger fixed size is used consistently across pipe, output-file, and in-place processing.

## 3. Verify behavior

- [x] 3.1 Run the Zig test suite covering `src/main.zig` file-processing behavior.
- [x] 3.2 Confirm no CLI, destination naming, exit-code, or created-file-permission semantics changed beyond the intended access-mode and fixed-buffer updates.
