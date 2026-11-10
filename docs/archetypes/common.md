# common only

`common/tasks.toml` is the base every repo includes first. On its own, it's the complete contract for a repo with
nothing to compile or test: a Markdown and YAML library such as `github-workflows`, `skills` or `.github`.

```toml
# mise.toml
[task_config]
includes = [".mise/common/tasks.toml"]
```

```makefile
# Makefile
include .mise/common/include.mk
```

## Tasks

| Task         | What it runs                                                                      |
| ------------ | --------------------------------------------------------------------------------- |
| `fmt`        | `fmt-prose` (`bun fmt`, markdownlint `--fix`), then `license`.                    |
| `lint`       | `license-check`, `lint-containers`, `lint-shell`, `lint-workflows`, `lint-prose`. |
| `ci`         | `lint`, then `docs-build`.                                                        |
| `pr`         | `fmt`, `lint`, then `docs-build`.                                                 |
| `commit`     | `./commit.sh` if present and executable.                                          |
| `license`    | addlicense: inject SPDX headers.                                                  |
| `actionlint` | actionlint over `.github/workflows`, on its own.                                  |
| `zizmor`     | zizmor over `.github/workflows`, on its own.                                      |
| `docs-build` | `uv sync`, then `zensical build` into `site/`. Skips without a `zensical.toml`.   |
| `serve`      | `uv sync`, then `zensical serve`: a live-reloading preview.                       |

There's no `build` or `test` task, so the reusable CI runs only `lint`. A common-only repo with a docs site builds it in
`ci` and `pr`, but CI's `lint` job won't.

## What common gives every archetype

Even when an archetype is included, common still supplies the shared passes the archetype's rollups call:

- **`license` / `license-check`**: SPDX headers via addlicense, with the house ignores plus `.licenseignore`.
- **`fmt-prose` / `lint-prose`**: `bun fmt` and markdownlint over every `*.md`.
- **`lint-workflows`**: actionlint, then zizmor, over `.github/workflows`.
- **`lint-containers`**: the composite of `lint-docker`, `lint-helm` and `lint-kustomize`.
- **`lint-shell`**: shellcheck over `scripts/` and `hack/`.
- **`commit`**: the agent-prepared commit handoff.
- **`docs-build` / `serve`**: the Zensical docs site, built or previewed via the shared `uv` pin. They run in the
  invoking directory and skip with a message when it has no `zensical.toml`. Every archetype's `build` ends with
  `docs-build` (terraform's `docs` does), so `pr` builds the site and CI checks it. A repo whose pages embed generated
  content overrides `docs-build` to generate it first; the release workflow's docs job runs the same task.

Every one of the lint passes is runtime-detected and no-ops silently when the repo has none of the files it checks. See
[Shared lint passes](../reference/lint.md) for each one in detail.

## Source

??? abstract "common/tasks.toml"

    ```toml
    --8<-- "common/tasks.toml"
    ```
