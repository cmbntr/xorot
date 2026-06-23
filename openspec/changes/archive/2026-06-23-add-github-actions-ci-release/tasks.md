## 1. Taskfile environment-aware release matrix

- [x] 1.1 Refactor `Taskfile.yml` so `task build` selects its target list from variables instead of a hardcoded inline list.
- [x] 1.2 Define a GitHub Actions-specific target list that excludes `x86_64-macos` and `aarch64-macos` while retaining `wasm32-wasi-none` and the current non-macOS release targets.
- [x] 1.3 Verify that `task build` still produces the expected `release/*.zip` artifact layout for the selected targets.

## 2. GitHub Actions CI and release workflow

- [x] 2.1 Add a GitHub Actions workflow that runs on pull requests targeting `main` and on pushed tags matching `v*`.
- [x] 2.2 Configure the workflow to install Nix, enable the Nix cache integration, and run repository commands through `nix develop`.
- [x] 2.3 In the pull request path, run `task test:full` and `task build` inside the Nix development environment.
- [x] 2.4 In the tag-release path, run `task build`, gather `release/*.zip`, and publish those assets to the corresponding GitHub Release with the required repository permissions.

## 3. Validation

- [x] 3.1 Validate the workflow configuration for syntax and trigger correctness.
- [x] 3.2 Run the relevant local verification commands needed to confirm the Taskfile changes and workflow assumptions before merging.
