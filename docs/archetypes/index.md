# Choosing an archetype

Every repo includes `common/tasks.toml` first, then **at most one** archetype. The archetype is the repo's primary
language: it decides what `fmt`, `lint`, `build` and `test` mean.

| Your repo is…                                        | Use                       |
| ---------------------------------------------------- | ------------------------- |
| A Go CLI or service (dotty, evolve, gh-claude)       | [go](go.md)               |
| A TypeScript library or a GitHub Action              | [node](node.md)           |
| A Python package, or a Zensical docs site with no Go | [python](python.md)       |
| A Terraform or OpenTofu module or environment        | [terraform](terraform.md) |
| Markdown and YAML with nothing to build or test      | [common only](common.md)  |

## What each archetype provides

| archetype | `fmt`                                             | `lint`                                                                            | `build`                            | `test`                       | extras                                |
| --------- | ------------------------------------------------- | --------------------------------------------------------------------------------- | ---------------------------------- | ---------------------------- | ------------------------------------- |
| go        | `go fmt`, `golangci-lint --fix`, prose, license   | golangci-lint, govulncheck, license, containers, shell, workflows, prose          | `go build` with version ldflags    | gotestsum, `-race`, coverage | `tidy`, `fuzz`, `snapshot`, `release` |
| node      | `check:fix` / `format` scripts, prose, license    | `check` / `typecheck` scripts, license, containers, shell, workflows, prose       | `build` script                     | `test:coverage` script       | —                                     |
| python    | license, `ruff format`, `ruff check --fix`, prose | `ruff check`, `ruff format --check`, license, containers, shell, workflows, prose | `uv build` and/or `zensical build` | pytest (+ pytest-cov)        | —                                     |
| terraform | `terraform fmt -recursive`, prose                 | validate, tflint, containers, shell, workflows, prose                             | —                                  | —                            | `init`, `plan`, `apply`, `docs`       |
| _common_  | prose, license                                    | license, containers, shell, workflows, prose                                      | —                                  | —                            | `commit`, `actionlint`, `zizmor`      |

Every archetype's `lint` includes everything common's does: license (except terraform), containers, shell, workflows and
prose. The common tasks (`commit`, `license`, `actionlint`, `zizmor`) are available in every repo.

## Root `mise.toml` per archetype

The root `mise.toml` differs only in what it pins and which archetype it includes:

| archetype     | root `[tools]`                         | `includes` second entry / `Makefile` include       |
| ------------- | -------------------------------------- | -------------------------------------------------- |
| go            | `go`, `go:…/govulncheck`               | `.mise/archetypes/go/…`                            |
| node          | `node`                                 | `.mise/archetypes/node/…`                          |
| python        | nothing (uv provisions Python)         | `.mise/archetypes/python/…`                        |
| terraform     | nothing (`opentofu` for a `tofu` repo) | `.mise/archetypes/terraform/…`                     |
| _common only_ | nothing                                | no second entry; `include .mise/common/include.mk` |

## Why archetypes don't stack

mise merges included task files whole-task, and the later include wins. Every archetype defines its own `fmt`, `lint`,
`build`, `test`, `ci` and `pr`, so including a second archetype would silently replace the first's rollups, not merge
with them.

Cross-language needs are carried **inside** an archetype instead:

- **A docs site** needs no archetype at all. common ships the Zensical tasks (`docs-build`, `serve`), so every repo has
  them; a Go repo with a CLI reference wires `docs-build` into a repo-local `docs` task.
- **A Go repo with an embedded web UI** adds a repo-local `ui` task and redefines `build` to run it before `go-build`.
  See [Extending & overriding](../concepts/extending.md#redefine-an-archetype-task).
- **The python archetype** is for repos whose _primary_ language is Python, including docs-only Zensical sites.

## Every archetype at a glance

All of them share some structure:

- **Leaf passes** are hidden tasks named for the language (`go-lint`, `node-build`, `py-test`, `tf-fmt`).
- **Rollups** are sequential composites, so mutating passes never race and `fmt` precedes `lint` inside `pr`.
- **`pr`** ends with `commit` everywhere except terraform, where it ends with `docs`.
- **Knobs** come from `[vars]` (structural) or the environment (per run). See [Knobs](../reference/knobs.md).
