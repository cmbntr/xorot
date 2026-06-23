## Why

The repository currently has local Nix and Task-based build/release tooling, but no repository-native GitHub Actions workflow to verify pull requests or publish tagged releases. That leaves release automation undocumented in practice, increases manual release work, and makes CI behavior diverge from the established `task build` entrypoint.

## What Changes

- Add a GitHub Actions workflow that validates open pull requests targeting `main` using the repository's Nix development environment and Taskfile entrypoints.
- Add tag-driven release automation that builds packaged artifacts on `v*` tags and publishes them to GitHub Releases.
- Keep `task build` as the single release build entrypoint while teaching the Taskfile to detect GitHub Actions and skip macOS targets there.
- Preserve current release asset naming and keep `wasm32-wasi-none` in both CI/release automation and local release builds.

## Capabilities

### New Capabilities
- `github-actions-release-automation`: GitHub-hosted CI for pull requests to `main` and tagged release publishing based on the repository's Nix and Task workflows.

### Modified Capabilities
- `zig-0-16-build-compatibility`: clarify that `task build` remains the release entrypoint while allowing the supported target matrix to vary by execution environment so GitHub Actions can skip macOS targets.

## Impact

- Adds `.github/workflows/release.yml` or equivalent workflow file(s).
- Updates `Taskfile.yml` target selection logic for local versus GitHub Actions execution.
- Affects GitHub Releases publishing flow, pull request validation, and release artifact generation.
- Reuses existing Nix dev shell dependencies and existing `task build` packaging behavior.
