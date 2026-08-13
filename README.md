# toolchain

Shared build tasks for the bitwise-media-group ecosystem — pinned developer tools, mise task archetypes, and house
lint/license policy — with a thin Makefile shim on top. Each repo consumes this library as a git submodule mounted at
`.mise/` (bumped by Dependabot's `gitsubmodule` ecosystem) and reduces its own `Makefile` to one include and its own
mise config to a few lines. (Formerly named `make`, from its Makefile-fragment era; GitHub redirects the old URL.)

See [RECOMMENDATION.md](RECOMMENDATION.md) for the original design rationale and the per-repo migration map (its
Makefile-fragment mechanics are superseded by the mise-task layout described here).

## Layout

```text
toolchain/                # this repo == the consumer's .mise/ directory
├── config.toml           # shared config: [settings], [tools] pins, [vars] knob
│                         #   defaults, and the universal tasks (license, prose
│                         #   lint, commit, actionlint, container/deploy/shell
│                         #   lint); consumers load it natively as
│                         #   .mise/config.toml
├── mise.lock              # per-platform sha256 + provenance for every pin
├── hack/                  # shell scripts behind the universal lint tasks
│                          #   (hadolint+grype, helm+kubescape, shellcheck)
├── tasks/                 # one self-contained task file per archetype
│   ├── go-cli.toml        #   go build/test/lint/release + zensical docs
│   ├── node-action.toml   #   biome + tsc + rollup + vitest
│   ├── node-lib.toml      #   tsup build + type-check
│   ├── docs-site.toml     #   zensical build/serve
│   ├── markdown-lib.toml  #   prose + license only
│   ├── agent-plugins.toml #   markdown-lib + the evolve eval suite
│   └── terraform.toml     #   init/plan/apply + tf fmt/lint/docs
└── mise.mk                # the whole make surface: thin forwarders to mise
```

## Usage

Add the submodule once, mounted at `.mise/`:

```sh
git submodule add https://github.com/bitwise-media-group/toolchain.git .mise
```

Create a root `mise.toml` that picks the archetype and sets any knobs, then reduce the `Makefile` to one line:

```toml
# mise.toml — a Go CLI (dotty, evolve, gh-claude)
[vars]
app = "dotty"
app_pkg = "./cmd"

[task_config]
includes = [".mise/tasks/go-cli.toml"]

# repo-local tasks live here too, e.g. the app-specific CLI reference:
[tasks.docs]
description = "regenerate the CLI reference and build the docs site"
dir = "{{cwd}}"
run = ["mise run build", "./dotty docs --out docs/cli --format markdown", "mise run docs-build"]
```

```makefile
# Makefile — the whole thing
include .mise/mise.mk

# append repo-local work to a canonical gate (runs before `mise run pr`):
pr: docs
```

Run `mise trust --all` once per clone (CI trusts the workspace automatically), and `make help` (or `mise tasks`) to list
what the repo exposes. Because the Makefile only forwards, `make <anything>` and `mise run <anything>` are
interchangeable — the Makefile exists for the CI contract and muscle memory, and the pipelines can move to invoking mise
natively without touching this library.

## The contract

The reusable CI workflow (`bitwise-media-group/github-workflows`) runs a matrix of **`make lint`**, **`make build`**,
**`make test`** (and opt-in **`make e2e`**), discovering which of those tasks a repo actually defines via
`mise tasks ls --name-only` and skipping the rest; release drives GoReleaser / Zensical directly. There are therefore
**no no-op stubs anywhere**: an archetype defines only real work (markdown-lib has no `build`/`test` at all), and a repo
that grows tests or an e2e suite just defines that task in its root `mise.toml [tasks]`. Every archetype also provides
**`fmt`**, **`ci`**, and **`pr`** for local use.

Extension works both ways:

- **make-side** — add a prerequisite in the repo Makefile (`pr: docs`, `lint: my-extra`). Prerequisites run **before**
  the forwarded task (the old library ran appended targets after `commit`; if ordering matters more precisely, use the
  mise-side mechanism).
- **mise-side** — add new tasks in the repo's root `mise.toml [tasks]`. To **redefine** a task the archetype already
  defines, put it in a repo-local task file included _after_ the archetype (later includes win whole-task; an included
  file also beats the same config's own `[tasks]` on name collisions):

  ```toml
  [task_config]
  includes = [".mise/tasks/go-cli.toml", "tasks.toml"] # tasks.toml redefines e.g. fuzz or pr
  ```

Aggregates (`fmt`, `lint`, `ci`, `pr`) are sequential task composites, so mutating passes never race and `fmt` always
precedes `lint` inside `pr`.

## Developer tools

Every tool (`addlicense`, `golangci-lint`, `govulncheck`, `gotestsum`, `goreleaser`, `syft`, `grype`, `hadolint`,
`helm`, `kubescape`, `shellcheck`, `terraform`, `tflint`, `terraform-docs`, `actionlint`, `prettier`,
`markdownlint-cli2`) floats on `"latest"` in `config.toml` (`node` on `"lts"`) with the real pin — exact version plus
per-platform sha256 checksums (and, where the publisher provides it, cosign/SLSA/GitHub-attestation provenance) — locked
in `mise.lock`. Tasks run with the pinned tools already on PATH — there is no `.bin/`, no `tools/go.mod`, no
`package.json` for linters, and no tool-path plumbing anywhere. mise installs a tool into its shared per-machine store
the first time a task needs it (verifying the checksum) and reuses it across every repo.

`dotty` and `evolve` are the exception: first-party CLIs, **task-scoped** (a `tools` map on just the tasks that run
them) rather than pinned in `[tools]`, so the mise-installed copy never shadows a locally installed one on the activated
PATH. They float on `latest` (override `dotty_version` / `evolve_version` in a repo's `[vars]` to pin) and live outside
`mise.lock` — see the `config.toml` header for the trade-offs. The terraform archetype carries dotty for its `tf-run.sh`
wrapper, which engages dotty only when the module directory has a `.env.dotty`; evolve only ever runs in a
plugin/marketplace repo, so only the `agent-plugins` archetype carries it — its `lint`/`test` gates and eval tasks
(`triggers`, `evals`, `all`, `report`) read the repo's `.evolve.{yaml,json,jsonc}`.

- The tooling runtimes themselves are locked too (`go`, `node`), provisioned by mise — no system Go or Node is needed.
- Bumping a tool for the **whole fleet** is one commit here (the daily updater below, or `mise lock --bump` by hand)
  plus a submodule bump in the consumers.
- A repo can override a tool version (or add tools) in its root `mise.toml [tools]` — the root config wins.
- **Never run `mise lock` or `mise upgrade` in a consumer repo**: the lockfile lives in this library, so a consumer-side
  re-lock writes into the submodule working tree.

Consuming repos should keep `coverage/` (and `node_modules/`) in `.gitignore`; `.bin/` is no longer created.

Dependabot has no mise ecosystem, so `.github/workflows/update-tools.yaml` replaces it — a thin caller of the reusable
`update-tools.yaml` in [`github-workflows`](https://github.com/bitwise-media-group/github-workflows), reused by any repo
with separately locked repo-local tools. It runs `mise lock --bump` daily, which re-resolves the `"latest"`/`"lts"`
selectors against releases at least 7 days old (`minimum_release_age = "7d"`, a Dependabot-style cooldown) and rewrites
`mise.lock` only — `config.toml` is never modified — then opens a single `fix(deps):` PR. Run it by hand with
`mise lock --bump` in this directory (or `mise lock --bump --dry-run --json` to just report). Note that unauthenticated
GitHub API calls can silently drop lockfile entries — set `GITHUB_TOKEN` (e.g. `GITHUB_TOKEN="$(gh auth token)"`) when
running it by hand.

## Knobs

Two tiers, replacing the old before-the-include make variables:

| tier                           | where                   | examples                                                                                                                   |
| ------------------------------ | ----------------------- | -------------------------------------------------------------------------------------------------------------------------- |
| structural (set once per repo) | root `mise.toml [vars]` | `app`, `app_pkg`, `build_tags`, `version_pkg`, `license_holder`, `terraform_binary`, `grype_fail_on`, `kubescape_severity` |
| per-invocation (runtime)       | environment variables   | `VERSION`, `COMMIT`, `DATE`, `LDFLAGS`, `MODULE`, `FUZZ`, `FUZZTIME`, `FUZZ_PKG`, `NPM_CI_FLAGS`                           |

`make build VERSION=1.2.3` still works — make exports command-line variables to the forwarded `mise run`, and the go-cli
scripts also accept the old spellings (`APP`, `APP_PKG`, …) from the environment.

## Other conventions the library assumes

- **License holder** is `BitWise Media Group Ltd` (override `license_holder` in `[vars]`). The license tasks ignore
  generated/vendored trees (`node_modules/`, `.mise/`, `.claude/`, `.venv/`, `coverage/`) by default; a repo's
  `.licenseignore` adds to that.
- **Prose is linted in every archetype, with zero per-repo config**: `fmt`/`lint` always run the pinned prettier +
  markdownlint-cli2 over all `*.md` from the repo root, excluding generated and vendored content (`CHANGELOG.md`,
  `node_modules/`, `.mise/`, `.venv/`, `.claude/`). The house defaults are this library's own `.prettierrc.yaml` /
  `.prettierignore` / `.markdownlint-cli2.yaml`, read from `.mise/` — a repo that commits its own copy of one of those
  files overrides that file wholesale. Node Action **npm scripts** are named `check`, `check:fix`, `typecheck`, `build`,
  `test:coverage` (biome + rollup + vitest); biome owns the code, prettier + markdownlint own the markdown.
- **Container, deploy, and shell artifacts are linted when present, with zero per-repo config**: every archetype's
  `lint` runs runtime-detected passes (scripts in `hack/`) that no-op silently when a repo has none of the artifacts. A
  root `Dockerfile`/`Dockerfile.*` gets hadolint plus a grype vulnerability scan of the external base images named in
  its `FROM` lines (pulled straight from the registry — no docker daemon; build-stage aliases, `scratch`, and
  unresolvable `${ARG}` refs are skipped, simple `ARG` defaults resolved). Each `helm/*/Chart.yaml` chart gets
  `helm lint` plus a kubescape misconfiguration scan; every `kustomization.yaml`/`.yml` directory gets a kubescape scan
  (`kind: Component` dirs are skipped — they only build through an overlay). Any `*.sh` under `scripts/` or `hack/` gets
  shellcheck. Gates fail at **high** severity by default (`grype_fail_on` / `kubescape_severity` in `[vars]`); grype
  passes `--only-fixed`, so only vulnerabilities an updated base image would fix break the build. Repos silence accepted
  findings with their own `.grype.yaml` / `.hadolint.yaml` (auto-loaded by the tools from the repo root) or a
  `.kubescape/exceptions.json` (passed as `--exceptions`). hadolint fails on any warning by default — use inline
  `# hadolint ignore=…` comments or `.hadolint.yaml`. First run on a machine downloads grype's vulnerability database
  (~200 MB, cached in `~/.cache/grype`) and kubescape's controls artifacts (`~/.kubescape`), so it needs network; the
  scans never contact a Kubernetes cluster (`KUBECONFIG` is pointed at nothing).
- **This repo's own layout is inverted**: `config.toml` sits at the root (it _is_ the consumer's `.mise/`), the dogfood
  archetype include lives in the root `mise.toml`, and `.mise/` here contains symlinks back to the root files so mise
  resolves the tools the same way it does in a consumer.
