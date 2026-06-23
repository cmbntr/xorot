## 1. Add package manifest

- [x] 1.1 Create root `build.zig.zon` with `.name = .xorot`, `.version = "0.3.0"`, `.minimum_zig_version = "0.16.0"`, `.dependencies = .{}`, and the agreed explicit `.paths` allow-list.
- [x] 1.2 Ensure the initial manifest omits `.fingerprint` so Zig can generate the stable package identity.

## 2. Generate and verify package identity

- [x] 2.1 Run `zig build` with Zig `0.16.0` to obtain Zig's suggested manifest fingerprint.
- [x] 2.2 Add the suggested `.fingerprint` field to `build.zig.zon` and confirm the build still succeeds without changing CLI behavior.

## 3. Validate scoped package behavior

- [x] 3.1 Verify the committed manifest still keeps the change CLI-only and does not add library/module exposure.
- [x] 3.2 Review the final `.paths` allow-list to confirm it includes only `build.zig`, `build.zig.zon`, `src`, `README.md`, and `LICENSE`.
