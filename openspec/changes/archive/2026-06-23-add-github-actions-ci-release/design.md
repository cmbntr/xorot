## Context

The repository already standardizes local builds around a Nix dev shell and `task build`, and existing GitHub Releases show a stable packaged-asset layout that should be preserved. What is missing is a repository-native GitHub Actions workflow that validates pull requests to `main` and publishes release assets for version tags without duplicating build logic outside the Taskfile.

The requested behavior adds one notable constraint: GitHub Actions should reuse `task build`, but the Taskfile must detect the Actions environment and skip macOS targets there while still keeping `wasm32-wasi-none` and the current full local target set. That means the release matrix becomes environment-sensitive rather than globally static.

## Goals / Non-Goals

**Goals:**
- Add GitHub Actions CI for open pull requests targeting `main`.
- Add GitHub Actions release publishing for `v*` tags.
- Keep `task build` as the only build entrypoint used by automation.
- Preserve current release artifact names and include `wasm32-wasi-none` in CI and release automation.
- Make Taskfile target selection detect `GITHUB_ACTIONS=true` and omit macOS targets in that environment.

**Non-Goals:**
- Replacing Nix, Task, or Zig with a different build orchestration tool.
- Introducing auto-releases on every `main` push.
- Changing runtime CLI behavior or the `xorot` artifact layout.
- Adding version synchronization enforcement between Git tags and `build.zig.zon` in this change.

## Decisions

### Use one GitHub Actions workflow with branch-sensitive and tag-sensitive jobs

The workflow will trigger on pull requests targeting `main` and on pushes of tags matching `v*`. PR validation and tagged release publication belong together because they share the same Nix bootstrap and Task entrypoints, and keeping them in one workflow reduces drift.

Alternative considered: split CI and release into separate workflow files. Rejected because this repository's automation surface is still small and the shared setup would be nearly identical.

### Reuse `task build` directly instead of creating CI-only or release-only build tasks

The workflow should call `nix develop --command task build` and `nix develop --command task test:full` rather than inventing `task build:release` or `task package`. This preserves the existing release entrypoint already documented by the repository and keeps GitHub Actions aligned with local usage.

Alternative considered: define new automation-specific tasks. Rejected because it would duplicate behavior, create another matrix source of truth, and weaken the current contract that `task build` is the release path.

### Make Taskfile target selection environment-aware

The Taskfile will define a full target list for local runs and a GitHub Actions target list that excludes `x86_64-macos` and `aarch64-macos`. The `build` task will choose between them based on `GITHUB_ACTIONS`.

This keeps the user-visible command stable while addressing the explicit request to skip macOS builds in GitHub Actions.

Alternative considered: keep Taskfile static and put the matrix logic in the workflow. Rejected because that would split release intent between two files and violate the preference to reuse `task build` as the sole release entrypoint.

### Keep release publishing tag-driven and asset-based

The release job will run only for `v*` tags, collect the generated `release/*.zip` outputs, and publish them to the corresponding GitHub Release. This matches the repository's existing manual release history and avoids creating releases for every merge.

Alternative considered: release on every push to `main`. Rejected because it would change the repository's release cadence and create noisy, less intentional releases.

## Risks / Trade-offs

- [GitHub-hosted Linux runners may still fail on one or more non-macOS cross-targets] -> Mitigation: keep the first automation pass narrow, reuse the currently working `task build`, and verify each produced artifact path directly in CI.
- [Environment-sensitive target selection may weaken the meaning of "supported target matrix"] -> Mitigation: update the relevant spec so local and GitHub Actions matrices are explicitly defined rather than implied.
- [A single workflow handling both PR and release paths can grow harder to read over time] -> Mitigation: keep job count low and structure triggers/conditions clearly.
- [Release publication can fail after a successful build due to permissions or asset upload issues] -> Mitigation: declare `contents: write` explicitly and separate build verification from release publishing conditions.

## Migration Plan

1. Add the GitHub Actions workflow file with PR verification and tag-release jobs.
2. Refactor `Taskfile.yml` so `task build` selects the GitHub Actions-safe target list when `GITHUB_ACTIONS=true`.
3. Validate that PR automation uses the Nix dev shell and succeeds with tests plus build packaging.
4. Validate that a `v*` tag run publishes the generated `release/*.zip` artifacts.

Rollback is straightforward: remove the workflow file and restore the previous static target list in `Taskfile.yml`.

## Open Questions

- None for this scoped change. The workflow policy, branch target, tag trigger, and WASI inclusion were all decided during exploration.
