# Daily workflow

Once a repo has adopted the toolchain, day-to-day use comes down to a handful of commands. They're the same in every
repo, whatever its language.

## The commands you'll use

| Command      | What it does                                                                        |
| ------------ | ----------------------------------------------------------------------------------- |
| `make help`  | List every task the repo exposes (same as `mise tasks`). It's the default target.   |
| `make fmt`   | Apply every auto-fix: the language formatter, prose formatting and license headers. |
| `make lint`  | Run every check-mode pass. This is the gate CI enforces.                            |
| `make test`  | Run the unit tests with coverage into `coverage/` (archetypes that have tests).     |
| `make build` | Build the binary, bundle, package or docs site (archetypes that build).             |
| `make ci`    | Run exactly the gates the reusable CI workflow runs.                                |
| `make pr`    | The full local gate before a pull request, ending with `./commit.sh` if present.    |

Because the Makefile only forwards, `make <anything>` and `mise run <anything>` are interchangeable. Use whichever you
prefer.

## Before every pull request: `make pr`

`make pr` is the one command to run before pushing. It runs the archetype's whole gate in order: format first, so lint
sees the fixed tree, then lint, test and build. For a Go repo:

```text
tidy → fmt → lint → test → build → commit
```

Rollups are sequential, so the mutating passes (`go fmt`, `prettier --write`, `addlicense`) never race each other, and
`fmt` always finishes before `lint` starts. If any step fails, the gate stops there.

The last step, `commit`, runs `./commit.sh` if the repo has an executable one. Coding agents that can't sign commits
from inside their sandbox prepare one, so a green local run flows straight into a commit you sign. If there's no
`commit.sh`, the step does nothing.

## Running one task

Any task runs on its own:

```sh
make lint
mise run lint        # identical
make actionlint      # just the workflow linter
make zizmor          # just the workflow security audit
```

Hidden helper tasks (the individual passes a rollup is built from, such as `go-lint` or `lint-prose`) don't show in
`make help`, but you can still run them by name:

```sh
mise run lint-prose
mise tasks --hidden  # list them all
```

## Passing values per invocation

Structural settings live in the root `mise.toml [vars]` (see [Knobs](../reference/knobs.md)). Values that change per run
are environment variables. Make exports command-line variables to the recipe, so both spellings work:

```sh
make build VERSION=1.2.3
VERSION=1.2.3 mise run build

make test GOOS=windows          # Go: compile-check the tests for windows
make fuzz FUZZ=FuzzParse FUZZTIME=1m FUZZ_PKG=./internal/parse
NODE_PACKAGE_MANAGER=pnpm make build
```

## Working on a docs site

Every repo has the Zensical tasks ready-made, from common:

```sh
make serve        # live-reloading preview (uv sync + zensical serve)
make docs-build   # one-off build into site/
```

A Go repo with a CLI reference usually adds its own `docs` task that regenerates the reference, then calls `docs-build`.
See [Extending & overriding](../concepts/extending.md).

## When a tool is missing

You never install linters by hand. If a task needs a tool that isn't on your machine yet, mise downloads the pinned
version, verifies its checksum against `mise.lock`, and carries on. The heavyweight tools are pinned `lazy`, so they're
only fetched the first time a task actually calls them. A Python-only repo never downloads golangci-lint.

If a Go repo has just bumped its `go` pin, rebuild govulncheck once so it's compiled by the new Go:

```sh
mise install -f "go:golang.org/x/vuln/cmd/govulncheck"
```

A fresh CI runner does this automatically.

## When something fails

- **Prose lint fails.** Run `make fmt`. Prettier and `markdownlint-cli2 --fix` fix most findings, and what's left is
  usually a line over 120 characters.
- **License check fails.** Run `make fmt` to inject the missing SPDX header. If the file is generated, add it to
  `.licenseignore` instead.
- **zizmor fails.** Fix the finding, or accept it inline with `# zizmor: ignore[audit-name]` or in a repo `zizmor.yml`.
- **A container or deploy scan fails.** See [Shared lint passes](../reference/lint.md) for how each scanner's findings
  are silenced per repo.
