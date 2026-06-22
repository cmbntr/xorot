## 1. Migrate Zig 0.16 build and I/O APIs

- [x] 1.1 Update `build.zig` to use Zig 0.16-compatible source path and executable/test module configuration.
- [x] 1.2 Update `src/main.zig` to use Zig 0.16-compatible stdin/stdout and reader/writer APIs while preserving the existing transform loop.
- [x] 1.3 Run `zig build` and resolve any remaining compiler errors introduced by the 0.13 -> 0.16 migration.

## 2. Restore release build compatibility

- [x] 2.1 Validate each `Taskfile.yml` release target against Zig 0.16 and update any invalid target names or unsupported entries.
- [x] 2.2 Run `task build` and confirm release artifacts are produced for every supported target kept in the matrix.
- [x] 2.3 Verify the migration does not change the `xorot` command interface or its stdin-to-stdout streaming behavior.
