# Extending & overriding

The archetypes cover what every repo of a kind shares. Anything app-specific stays in the repo. There are two ways to
extend the gates, and one way to replace a task outright.

## Add a make-side prerequisite

The simplest extension is a prerequisite in the repo's Makefile, under the include:

```makefile
include .mise/archetypes/go/include.mk

pr: docs
lint: my-extra-check
```

Make runs prerequisites **before** the forwarded target, so `make pr` runs `mise run docs`, then `mise run pr`. This
repo uses the same mechanism to shellcheck its own scripts: `lint: lint-scripts`.

!!! note

    The prerequisite only applies to the make spelling. `mise run pr` skips it. If ordering matters more precisely, or
    you want `mise run` and `make` to agree, use a mise-side extension instead.

## Add a repo-local task

New tasks go in the root `mise.toml` under `[tasks]`:

```toml
[tasks.docs]
description = "regenerate the CLI reference and build the docs site"
dir = "{{cwd}}"
run = [
  { task = "build" },
  "./dotty docs --out docs/cli --format markdown",
  { task = "docs-build" },
]
```

Repo-local tasks can call any library task by name (`build`, `docs-build`) and use the pinned tools on `PATH`. The make
shim's `.DEFAULT` catch-all forwards unknown targets, so `make docs` works without touching the Makefile.

When the list grows, move the tasks to a separate file in the same simplified format the library uses. dotty and evolve
keep theirs in a root `tasks.toml`.

## Redefine an archetype task

To **replace** a task the archetype already defines, put the replacement in a repo-local task file included **after**
the archetype:

```toml
[task_config]
includes = [
  ".mise/common/tasks.toml",
  ".mise/archetypes/go/tasks.toml",
  "tasks.toml", # redefines e.g. fuzz or pr
]
```

Two merge rules make this work:

- Later includes win, whole-task.
- An included file also beats the same config's own `[tasks]` on a name collision.

So a `[tasks.fuzz]` block in `mise.toml` would **not** override the archetype's `fuzz`, but a `[fuzz]` entry in an
included `tasks.toml` does. dotty uses this to bake its default fuzz target into the task:

```toml
# tasks.toml (included after the go archetype)
[fuzz]
description = "fuzz one target (FUZZ=FuzzExtractFlags FUZZTIME=20s FUZZ_PKG=./internal/cli)"
dir = "{{cwd}}"
run = """
set -eu
go test -run '^$' -fuzz "^${FUZZ:-FuzzExtractFlags}$" -fuzztime "${FUZZTIME:-20s}" "${FUZZ_PKG:-./internal/cli}"
"""
```

Replacement is whole-task, so the new definition must do everything the old one did. To add one step to a rollup, copy
the archetype's `run` list and insert your step. evolve builds its embedded report viewer before the binary:

```toml
# tasks.toml (included after the go archetype)
[build]
description = "build the application binary (embeds the report-viewer UI)"
run = [{ task = "ui" }, { task = "go-build" }]
```

## Override a tool or a knob

The repo's root `mise.toml` has higher precedence than `.mise/config.toml`, so:

- **A `[tools]` entry** overrides the shared pin. For example, a Go repo whose Go outpaces the shared golangci-lint pins
  its own `"aqua:golangci/golangci-lint"`.
- **A `[vars]` entry** overrides the knob default. See [Knobs](../reference/knobs.md).
- **A list setting** like `minimum_release_age_excludes` merges across configs, so a repo can append its own entries.

## Override house prose config

Prettier, markdownlint and their ignore files are read from `.mise/` unless the repo commits its own copy:

| File                      | Effect of committing your own                                  |
| ------------------------- | -------------------------------------------------------------- |
| `.prettierrc.yaml`        | Replaces the house prettier options (120 columns, prose wrap). |
| `.prettierignore`         | Replaces the house prettier ignore list.                       |
| `.markdownlint-cli2.yaml` | Replaces the house markdownlint rules, globs and ignores.      |

A repo's copy overrides that file **wholesale**: nothing merges. Start from the library's version and change what you
need.

## What not to override

- **Never put `[task_config]` in `config.toml`.** It's the library's file, and its include paths would resolve against
  your repo.
- **Never stack archetypes.** Carry the second language's needs inside your primary archetype with repo-local tasks.
- **Never re-lock the shared pins** (`mise lock`, `mise upgrade`) in a consumer. Change shared pins here instead.
