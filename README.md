# toolchain

Shared build tasks for the bitwise-media-group ecosystem — pinned developer tools, mise task archetypes, and house
lint/license policy — with a thin Makefile shim on top. Each repo consumes this library as a git submodule mounted at
`.mise/` (bumped to each new semver tag by Renovate's `git-submodules` manager), pins its own language runtime in its
root `mise.toml`, and reduces its `Makefile` to one include. (Formerly named `make`, from its Makefile-fragment era;
GitHub redirects the old URL.)

## Layout

```text
toolchain/                    # this repo == the consumer's .mise/ directory
├── config.toml               # shared config: [settings], [tools] pins, [vars] knob
│                             #   defaults — NO tasks; consumers load it natively as
│                             #   .mise/config.toml
├── mise.lock                 # per-platform sha256 + provenance for every pin
├── .prettierrc.yaml          # house prose defaults, read from .mise/ by every
├── .prettierignore           #   consumer that does not commit its own copy
├── .markdownlint-cli2.yaml   #   (see "Other conventions")
├── common/                   # what every repo gets, whatever its language
│   ├── tasks.toml            #   commit, license, prose fmt/lint, actionlint + zizmor,
│   │                         #   container/helm/kustomize/shell lint, and the
│   │                         #   fmt/lint/ci/pr rollups for a common-only repo
│   ├── include.mk            #   the whole make surface: thin forwarders to mise
│   └── scripts/              #   the shell behind the tasks (shellcheck-clean)
└── archetypes/               # exactly ONE per repo, included after common
    ├── go/                   #   build/test/lint/fuzz/release + zensical docs
    ├── node/                 #   npm-script contract: check/typecheck/build/test
    ├── python/               #   uv-native: ruff + pytest + uv build + zensical
    └── terraform/            #   init/plan/apply + tf fmt/lint/docs
        ├── tasks.toml        #   each archetype: its tasks + fmt/lint/ci/pr rollups
        ├── include.mk        #   its make shim (pulls in common/include.mk)
        └── scripts/          #   its task scripts
```

## Usage

Add the submodule once, mounted at `.mise/` (Renovate then proposes a bump whenever a new `vX.Y.Z` tag is cut):

```sh
git submodule add https://github.com/bitwise-media-group/toolchain.git .mise
```

Create a root `mise.toml` that pins the repo's runtime, includes `common` and then its archetype, and sets any knobs;
then reduce the `Makefile` to one line:

```toml
# mise.toml — a Go CLI (dotty, evolve, gh-claude)
[tools]
go = "1.27.1"
"go:golang.org/x/vuln/cmd/govulncheck" = "1.6.0" # must be built by the repo's own Go

[vars]
app = "dotty"
app_pkg = "./cmd"

[task_config]
includes = [".mise/common/tasks.toml", ".mise/archetypes/go/tasks.toml"] # common first, archetype second

# repo-local tasks live here too, e.g. the app-specific CLI reference:
[tasks.docs]
description = "regenerate the CLI reference and build the docs site"
dir = "{{cwd}}"
run = ["mise run build", "./dotty docs --out docs/cli --format markdown", "mise run docs-build"]
```

```makefile
# Makefile — the whole thing
include .mise/archetypes/go/include.mk

# append repo-local work to a canonical gate (runs before `mise run pr`):
pr: docs
```

Per archetype, the root `mise.toml` differs only in what it pins and includes:

| archetype     | root `[tools]`                         | `includes` second entry / `Makefile` include       |
| ------------- | -------------------------------------- | -------------------------------------------------- |
| go            | `go`, `go:…/govulncheck`               | `.mise/archetypes/go/…`                            |
| node          | `node`                                 | `.mise/archetypes/node/…`                          |
| python        | nothing (uv provisions Python)         | `.mise/archetypes/python/…`                        |
| terraform     | nothing (`opentofu` for a `tofu` repo) | `.mise/archetypes/terraform/…`                     |
| _common only_ | nothing                                | no second entry; `include .mise/common/include.mk` |

A Markdown/YAML repo with nothing to build or test (github-workflows, skills, `.github`) includes only `common`:

```toml
[task_config]
includes = [".mise/common/tasks.toml"]
```

```makefile
include .mise/common/include.mk
```

**Archetypes do not stack**: mise merges included task files whole-task with the later include winning, so a second
archetype would silently replace the first's `fmt`/`lint`/`build`/`test`/`ci`/`pr` rollups. Cross-language needs are
carried _inside_ an archetype instead — the go archetype ships the zensical docs tasks (`docs-build`, `serve`, `sync`),
so a Go repo with a docs site includes only `archetypes/go` and wires `docs-build` into a repo-local `docs` task. The
python archetype is for repos whose primary language is Python (including docs-only zensical sites).

Run `mise trust --all` once per clone (CI trusts the workspace automatically), and `make help` (or `mise tasks`) to list
what the repo exposes. Because the Makefile only forwards, `make <anything>` and `mise run <anything>` are
interchangeable — the Makefile exists for the CI contract and muscle memory, and the pipelines can move to invoking mise
natively without touching this library.

## The contract

The reusable CI workflow (`bitwise-media-group/github-workflows`) runs a matrix of **`make lint`**, **`make build`**,
**`make test`** (and opt-in **`make e2e`**), discovering which of those tasks a repo actually defines via
`mise tasks ls --name-only` and skipping the rest; release drives GoReleaser / Zensical directly. There are therefore
**no no-op stubs anywhere**: an archetype defines only real work (a common-only repo has no `build`/`test` at all), and
a repo that grows tests or an e2e suite just defines that task in its root `mise.toml [tasks]`. The one tolerated
exception is the node archetype, whose optional npm scripts run through `npm run --if-present` — a library with no
`test:coverage` script gets a trivially passing `test`. Every archetype also provides **`fmt`**, **`ci`**, and **`pr`**
for local use.

Extension works both ways:

- **make-side** — add a prerequisite in the repo Makefile (`pr: docs`, `lint: my-extra`). Prerequisites run **before**
  the forwarded task (the old library ran appended targets after `commit`; if ordering matters more precisely, use the
  mise-side mechanism).
- **mise-side** — add new tasks in the repo's root `mise.toml [tasks]`. To **redefine** a task the archetype already
  defines, put it in a repo-local task file included _after_ the archetype (later includes win whole-task; an included
  file also beats the same config's own `[tasks]` on name collisions):

  ```toml
  [task_config]
  # tasks.toml redefines e.g. fuzz or pr
  includes = [".mise/common/tasks.toml", ".mise/archetypes/go/tasks.toml", "tasks.toml"]
  ```

Rollups (`fmt`, `lint`, `ci`, `pr`) are sequential task composites, so mutating passes never race and `fmt` always
precedes `lint` inside `pr`.

### Archetypes

| archetype | `fmt`                                             | `lint`                                                                            | `build`                            | `test`                       | extras                                                       |
| --------- | ------------------------------------------------- | --------------------------------------------------------------------------------- | ---------------------------------- | ---------------------------- | ------------------------------------------------------------ |
| go        | `go fmt`, `golangci-lint --fix`, prose, license   | golangci-lint, govulncheck, license, containers, shell, workflows, prose          | `go build` with version ldflags    | gotestsum, `-race`, coverage | `tidy`, `fuzz`, `snapshot`, `release`, `docs-build`, `serve` |
| node      | `npm run check:fix` / `format`, prose, license    | `npm run check` / `typecheck`, license, containers, shell, workflows, prose       | `npm run build`                    | `npm run test:coverage`      | —                                                            |
| python    | license, `ruff format`, `ruff check --fix`, prose | `ruff check`, `ruff format --check`, license, containers, shell, workflows, prose | `uv build` and/or `zensical build` | pytest (+ pytest-cov)        | `docs-build`, `serve`                                        |
| terraform | `terraform fmt -recursive`, prose                 | validate, tflint, containers, shell, workflows, prose                             | —                                  | —                            | `init`, `plan`, `apply`, `docs`                              |
| _common_  | prose, license                                    | license, containers, shell, workflows, prose                                      | —                                  | —                            | `commit`, `actionlint`, `zizmor`                             |

- **go** — `go` and `govulncheck` are pinned by the repo (govulncheck must be `go install`ed by the same Go that builds
  the module). Structural knobs `app`, `app_pkg`, `build_tags`, `version_pkg`, `goos` come from `[vars]`. `goos` is a
  space-separated GOOS list (`goos = "linux darwin windows"`; empty = the host's GOOS only): `lint` runs golangci-lint
  and govulncheck once per entry, and `test` runs the full suite on the host's GOOS plus a compile-only `go test -c`
  pass for every other entry, since cross-compiled test binaries cannot execute. `GOOS` in the environment overrides the
  list per invocation (`make test GOOS=windows`). `docs` is left to the repo (a CLI reference is app-specific) with
  `docs-build`/`serve`/`sync` (zensical via uv) ready to wire in.
- **node** — one archetype for libraries and GitHub Actions, on the npm-script contract `check`, `check:fix`, `format`,
  `typecheck`, `build`, `test:coverage`; `typecheck` and `build` are required, the rest optional (`--if-present`).
  `npm ci` runs with `npm_ci_flags` (`--ignore-scripts --no-fund` by default); an action repo that runs lifecycle
  scripts sets `npm_ci_flags = ""`. biome owns the code, prettier + markdownlint own the markdown.
- **python** — uv-native: `uv` (a shared pin) provisions Python from `.python-version`/`requires-python` and the project
  environment from `pyproject.toml`/`uv.lock`; ruff, pytest and pytest-cov come from the project's dev dependencies. A
  project without ruff or pytest (a docs-only site) skips those passes with a message. `build` runs `uv build` when
  `pyproject.toml` has a `[build-system]` and `zensical build` when a `zensical.toml` is present.
- **terraform** — every task runs in the invoking directory (`environments/<name>/`); `tf-run.sh` injects secrets via
  `dotty` only when the module carries a `.env.dotty`. `terraform_binary = "tofu"` switches to OpenTofu. No license
  tasks (addlicense would stamp `.tf` files).

## Developer tools

Every developer CLI (`addlicense`, `golangci-lint`, `gotestsum`, `goreleaser`, `syft`, `grype`, `cosign`, `hadolint`,
`helm`, `kubescape`, `shellcheck`, `terraform`, `tflint`, `terraform-docs`, `actionlint`, `zizmor`, `uv`, `prettier`,
`markdownlint-cli2`) is pinned in `config.toml [tools]` — exact version plus per-platform sha256 checksums (and, where
the publisher provides it, cosign/SLSA/GitHub-attestation provenance) — locked in `mise.lock`. Tasks run with the pinned
tools already on PATH — there is no `tools/go.mod`, no `package.json` for linters, and no tool-path plumbing anywhere.
mise installs a tool into its shared per-machine store the first time a task needs it (verifying the checksum) and
reuses it across every repo.

**Language runtimes are per-repo**, not fleet-wide, so each repo tracks its own version at its own cadence:

- **Go repos** pin `go` and `go:golang.org/x/vuln/cmd/govulncheck` in their root `mise.toml [tools]`. govulncheck
  publishes no binaries and must be compiled by the repo's own Go, which is why it left the shared pins with it. mise
  keys a `go:` install by the tool version alone, so after bumping `go` on a machine that already has govulncheck,
  rebuild it once: `mise install -f "go:golang.org/x/vuln/cmd/govulncheck"` (a fresh CI runner compiles it with the
  pinned Go automatically). golangci-lint, gotestsum and goreleaser stay shared (prebuilt binaries); override
  `golangci-lint` in the root `[tools]` if the repo's Go outpaces the shared pin.
- **Node repos** pin `node` in their root `[tools]`. The library _also_ pins `node`, purely as the runtime for the
  npm-backed prettier and markdownlint-cli2 (mise's npm backend does not provision node, and repos must be able to lint
  prose without a `package.json`); the repo's root pin takes precedence, so the shared one never dictates a Node repo's
  runtime.
- **Python repos** pin nothing: `uv` provisions the interpreter. A repo that wants a mise-managed Python adds `python`
  to its root `[tools]`.

Each repo's own Renovate bumps its runtime pins in its root `mise.toml` (the org preset already covers root
`mise.toml`). A repo can override any shared tool version (or add tools) in its root `mise.toml [tools]` — the root
config wins.

`dotty` is the exception: our own first-party CLI, never mise-installed at all. The terraform archetype's `tf-run.sh`
wrapper invokes it only to inject secrets when a module directory carries a `.env.dotty` — a local-dev convenience
that's never present in CI — so the wrapper checks for `dotty` on PATH itself and runs the command uninjected if it's
missing, rather than having mise provision (and thereby pin/shadow) a CLI most tasks never touch.

Consuming repos should keep `coverage/` (and `node_modules/`, `.venv/`, `site/`, `dist/` as applicable) in `.gitignore`.

### Updating the shared pins

Bumping a shared tool for the **whole fleet** is one commit here plus a submodule bump in the consumers. The org
Renovate bot ([`renovate-config`](https://github.com/bitwise-media-group/renovate-config)) does it: every `[tools]`
entry in `config.toml` is an exact pin, and the bot opens one PR per tool that bumps the pin and regenerates `mise.lock`
(`mise lock`) in the same commit, under the org's 3-day release cooldown (`minimumReleaseAge`, surfaced as the
`renovate/stability-days` check). Stable minor/patch bumps automerge; majors and 0.x wait for review. The repo-local
`.github/renovate.json5` teaches the mise manager about the root `config.toml` (the dogfood inversion hides it from the
default file patterns) and lands tool bumps as `fix(deps):` so release-please cuts a patch for consumers.

To bump by hand: edit the pin in `config.toml` and run `mise lock`. Unauthenticated GitHub API calls can silently drop
lockfile entries, so set `GITHUB_TOKEN` (e.g. `GITHUB_TOKEN="$(gh auth token)"`) first. **Never run `mise lock` or
`mise upgrade` in a consumer repo**: the lockfile lives in this library, so a consumer-side re-lock writes into the
submodule working tree.

## Knobs

Two tiers, replacing the old before-the-include make variables:

| tier                           | where                   | examples                                                                                                                                                                  |
| ------------------------------ | ----------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| structural (set once per repo) | root `mise.toml [vars]` | `app`, `app_pkg`, `build_tags`, `version_pkg`, `goos`, `license_holder`, `npm_ci_flags`, `terraform_binary`, `grype_fail_on`, `kubescape_severity`, `zizmor_min_severity` |
| per-invocation (runtime)       | environment variables   | `VERSION`, `COMMIT`, `DATE`, `LDFLAGS`, `MODULE`, `GOOS`, `FUZZ`, `FUZZTIME`, `FUZZ_PKG`, `NPM_CI_FLAGS`                                                                  |

`make build VERSION=1.2.3` still works — make exports command-line variables to the forwarded `mise run`, and the go
scripts also accept the old spellings (`APP`, `APP_PKG`, …) from the environment.

## Other conventions the library assumes

- **License holder** is `BitWise Media Group Ltd` (override `license_holder` in `[vars]`). The license tasks ignore
  generated/vendored trees (`node_modules/`, `.mise/`, `.claude/`, `.venv/`, `coverage/`) and an agent-prepared
  `commit.sh` by default; a repo's `.licenseignore` adds to that. Every archetype but terraform runs them — a node
  action repo whose committed `dist/` bundle must stay byte-identical to the build output lists `dist/**` in its
  `.licenseignore`.
- **Prose is linted in every archetype, with zero per-repo config**: `fmt`/`lint` always run the pinned prettier +
  markdownlint-cli2 over all `*.md` from the repo root, excluding generated and vendored content (`CHANGELOG.md`,
  `node_modules/`, `.mise/`, `.venv/`, `.claude/`). The house defaults are this library's own `.prettierrc.yaml` /
  `.prettierignore` / `.markdownlint-cli2.yaml`, read from `.mise/` — a repo that commits its own copy of one of those
  files overrides that file wholesale.
- **GitHub Actions workflows are linted in every archetype, with zero per-repo config**: `lint` runs actionlint (syntax,
  expressions, embedded shell) and zizmor (security: injection, unpinned actions, excessive permissions, dangerous
  triggers) over `.github/workflows`, no-op where there are none. zizmor fails the gate at **low** severity and up by
  default (`zizmor_min_severity` in `[vars]`); silence an accepted finding inline (`# zizmor: ignore[audit-name]`) or in
  a repo `zizmor.yml`. zizmor's online-only audits run only when `GH_TOKEN` is exported (it prints a notice otherwise).
  `make actionlint` / `make zizmor` run either tool alone.
- **Container, deploy, and shell artifacts are linted when present, with zero per-repo config**: every archetype's
  `lint` runs runtime-detected passes (scripts in `common/scripts/`) that no-op silently when a repo has none of the
  artifacts. A root `Dockerfile`/`Dockerfile.*` gets hadolint plus a grype vulnerability scan of the external base
  images named in its `FROM` lines (pulled straight from the registry — no docker daemon; build-stage aliases,
  `scratch`, and unresolvable `${ARG}` refs are skipped, simple `ARG` defaults resolved). Each `helm/*/Chart.yaml` chart
  gets `helm lint` plus a kubescape misconfiguration scan; every `kustomization.yaml`/`.yml` directory gets a kubescape
  scan (`kind: Component` dirs are skipped — they only build through an overlay). Any `*.sh` under `scripts/` or `hack/`
  gets shellcheck. Gates fail at **high** severity by default (`grype_fail_on` / `kubescape_severity` in `[vars]`);
  grype passes `--only-fixed`, so only vulnerabilities an updated base image would fix break the build. Repos silence
  accepted findings with their own `.grype.yaml` / `.hadolint.yaml` (auto-loaded by the tools from the repo root) or a
  `.kubescape/exceptions.json` (passed as `--exceptions`). hadolint fails on any warning by default — use inline
  `# hadolint ignore=…` comments or `.hadolint.yaml`. First run on a machine downloads grype's vulnerability database
  (~200 MB, cached in `~/.cache/grype`) and kubescape's controls artifacts (`~/.kubescape`), so it needs network; the
  scans never contact a Kubernetes cluster (`KUBECONFIG` is pointed at nothing).
- **This repo's own layout is inverted**: `config.toml`, `common/` and `archetypes/` sit at the root (it _is_ the
  consumer's `.mise/`), the dogfood include lives in the root `mise.toml`, and `.mise/` here contains symlinks back to
  the root entries so mise resolves tools and scripts the same way it does in a consumer.

## Migrating from v2 (`tasks/<archetype>.toml` + `mise.mk`)

1. Move the runtime pins into the repo's root `mise.toml [tools]`: `go` + `"go:golang.org/x/vuln/cmd/govulncheck"` for a
   Go repo, `node` for a Node repo (Python repos pin nothing).
2. Replace `includes = [".mise/tasks/<archetype>.toml"]` with
   `includes = [".mise/common/tasks.toml", ".mise/archetypes/<lang>/tasks.toml"]` — `go-cli` → `go`, `node-lib` /
   `node-action` → `node` (an action repo adds `npm_ci_flags = ""` to `[vars]`), `docs-site` → `python`, `markdown-lib`
   → common only.
3. Replace `include .mise/mise.mk` with `include .mise/archetypes/<lang>/include.mk` (or
   `include .mise/common/include.mk`).
4. Node repos: the license tasks now run — add `dist/**` (and anything else generated) to `.licenseignore`; make sure a
   `typecheck` script exists.
5. Workflow lint now includes zizmor: run `make lint` once and address or ignore its findings.
6. `.bin/` is no longer created; drop it from `.gitignore` and delete any stale copy.
