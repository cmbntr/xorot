## Context

The repository is a small Zig CLI that reads from stdin, transforms bytes, and writes to stdout. The current build pipeline is centered on `task build`, which loops over several release targets and invokes `zig build install` to package binaries. After upgrading the toolchain from Zig 0.13 to Zig 0.16, the project no longer builds because the code still uses pre-0.16 build-script path plumbing and pre-0.16 stdlib I/O APIs.

The affected surface area is intentionally small: `build.zig` defines the executable, install, run, and test steps; `src/main.zig` reads and writes through stdin/stdout; `Taskfile.yml` defines the release matrix. The change should restore compatibility without changing the user-facing `xorot` algorithm, CLI shape, or artifact layout beyond target-name corrections required by Zig 0.16.

## Goals / Non-Goals

**Goals:**
- Restore successful compilation with Zig 0.16.
- Keep `xorot` runtime behavior identical for stdin-to-stdout byte transformation.
- Keep the release workflow based on `task build` and preserve packaging across the supported target matrix.
- Minimize the code changes to the specific APIs that changed between Zig 0.13 and 0.16.

**Non-Goals:**
- Changing the `xorot` transformation algorithm.
- Redesigning the release process or switching build tooling.
- Adding new CLI flags, configuration, or non-build-related features.
- Broad refactors outside the files directly affected by the Zig migration.

## Decisions

### Update build script to Zig 0.16-native source path and module APIs
`build.zig` will be migrated from the older `root_source_file = .{ .src_path = ... }` form to the current `b.path(...)`-based setup, and if required by the compiler, executable/test setup will move to `root_module = b.createModule(...)`.

Rationale: this is the first likely parse-time failure point and is directly called out by current Zig 0.16 examples.

Alternatives considered:
- Keep the old structure and try to patch only field names. Rejected because the old lazy-path shape is already obsolete and likely to fail again on nearby APIs.
- Pin the project back to Zig 0.13. Rejected because the repository already moved the dev environment to Zig 0.16.

### Update application I/O to Zig 0.16 stdlib interfaces
`src/main.zig` will stop depending on `std.io`, `getStdIn`, `getStdOut`, and `std.fs.File.Reader/Writer` names that changed during the I/O interface migration. The implementation will adopt the current 0.16 stdin/stdout entry points and reader/writer types while keeping the `xorot` loop and byte semantics unchanged.

Rationale: the runtime code is very small, so the least risky path is to adapt only the changed I/O entry points and types.

Alternatives considered:
- Rewrite `xorot` to use a different buffering approach. Rejected because the current buffer loop is already simple and behaviorally correct.
- Inline stdin/stdout handling directly into `main` without a helper. Rejected unless required by the new API, because the existing helper keeps the transform logic isolated.

### Validate the release target list against Zig 0.16 target naming
The `task build` matrix will be checked for target strings that changed or are no longer valid under Zig 0.16, with `wasm32-wasi-none` the main suspect.

Rationale: even after code compiles locally, one stale target name can keep `task build` failing late in the release loop.

Alternatives considered:
- Leave the target list unchanged until a later cleanup. Rejected because the change goal is restoring `task build`, not only native compilation.

## Risks / Trade-offs

- [Zig 0.16 I/O APIs may require a slightly different `main` shape than expected] -> Mitigation: verify the exact compiler errors and adapt the smallest viable pattern that preserves streaming stdin/stdout behavior.
- [The release matrix may contain multiple target-specific failures beyond naming] -> Mitigation: validate targets one by one after the source migration and narrow changes to only targets that fail under 0.16.
- [Using newer build APIs may require touching both executable and test setup] -> Mitigation: migrate both `addExecutable` and `addTest` consistently in the same change.
- [Cross-target packaging behavior may differ from 0.13 even after compilation succeeds] -> Mitigation: verify `task build` end-to-end, not only `zig build` on the host platform.
