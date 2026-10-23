# Overview

The toolchain is the shared build library for every repository in the BitWise Media Group fleet. It's one git repository
holding three things:

- **Pinned developer tools**: every linter, scanner, test runner and release tool the fleet uses, each pinned to an
  exact version with per-platform sha256 checksums in `mise.lock`.
- **Task archetypes**: [mise](https://mise.jdx.dev) task files that define the `fmt`, `lint`, `build`, `test`, `ci` and
  `pr` gates for each kind of repo: Go, Node, Python, Terraform, or plain Markdown/YAML.
- **House policy**: the license header, prose formatting and workflow security rules every repo follows, with defaults
  that need no per-repo config.

Each consuming repo mounts the library as a git submodule at `.mise/`. mise loads `.mise/config.toml` natively, so the
pinned tools are on `PATH` inside every task with no setup step. The repo's root `mise.toml` picks the task files and
pins its own language runtime, and its `Makefile` is a single `include` line.

```text
my-repo/
├── .mise/            ← this library, as a git submodule
│   ├── config.toml   ← pinned tools + knob defaults (loaded by mise automatically)
│   ├── mise.lock     ← per-platform checksums for every pin
│   ├── common/       ← tasks every repo gets
│   └── archetypes/   ← go / node / python / terraform tasks
├── mise.toml         ← runtime pin + includes + knobs + repo-local tasks
└── Makefile          ← include .mise/archetypes/<lang>/include.mk
```

## Why it exists

Without a shared library, each repo carries its own build glue: Makefile fragments, a `tools/go.mod` or a linter
`package.json`, and its own choice of linter versions. Upgrading one linter across the fleet then takes a pull request
per repo. The toolchain follows one rule instead: **tool versions and task definitions live here, and repos consume
them**. (The library began as shared Makefile fragments, which is why it was once called `make`. GitHub still redirects
the old URL.)

- **One upgrade path.** Renovate bumps a pin in this repo and re-locks the checksums. release-please cuts a release, and
  every consumer gets a submodule-bump PR. See [Releases & updates](../concepts/releases.md).
- **One contract.** The reusable CI workflow runs `make lint`, `make build` and `make test` in every repo, whatever its
  language. See [The CI contract](../concepts/contract.md).
- **No tool plumbing.** No `.bin/` directory, no `go install` of linters, no `npx`. mise installs each pinned tool into
  a shared per-machine store the first time a task needs it, verifies its checksum, and reuses it across every repo.

## What runs where

| Concern                         | Lives in                                      | Who changes it              |
| ------------------------------- | --------------------------------------------- | --------------------------- |
| Shared tool pins, knob defaults | `.mise/config.toml` + `.mise/mise.lock`       | this repo (Renovate)        |
| Task definitions                | `.mise/common/`, `.mise/archetypes/<lang>/`   | this repo                   |
| Language runtime (`go`, `node`) | the repo's root `mise.toml [tools]`           | the repo (its own Renovate) |
| Which archetype, knob overrides | the repo's root `mise.toml`                   | the repo                    |
| Repo-specific tasks             | the repo's root `mise.toml [tasks]` or a file | the repo                    |
| The `make` surface              | `.mise/common/include.mk` (via one `include`) | this repo                   |
| CI orchestration                | `bitwise-media-group/github-workflows`        | that repo                   |

## Prerequisites

You need two things on your machine:

- **mise**: `brew install mise`, or see the [mise install guide](https://mise.jdx.dev/getting-started.html). Every other
  tool comes from the pins.
- **GNU make** (or the macOS system make), only if you want the `make <task>` spelling. `mise run <task>` works without
  it.

The first run of a task that needs a tool you've never installed downloads it, so expect a short pause the first time
you run `make lint` on a new machine. The container and deploy scans also fetch vulnerability data on first use (see
[Shared lint passes](../reference/lint.md#containers-and-deploy-manifests)).

## Next steps

- [Adopt the toolchain](adopt.md) in a new or existing repository.
- Learn the [daily workflow](daily-workflow.md): `make pr`, `make help`, running single tasks.
- Read [Architecture](../concepts/architecture.md) to see how the pieces fit together.
