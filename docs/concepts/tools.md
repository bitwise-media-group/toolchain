# Pinned tools

Every developer CLI the fleet uses is pinned once, in `config.toml [tools]`, and locked in `mise.lock`. Tasks run with
those tools on `PATH`. There's no `tools/go.mod`, no linter `package.json`, and no tool-path plumbing anywhere.

## How a pin works

Each entry names the tool by an **explicit backend** and an **exact version**:

```toml
"aqua:golangci/golangci-lint" = { version = "2.14.0", lazy = true, lazy_bins = "golangci-lint" }
"npm:markdownlint-cli2" = "0.24.0"
"github:google/addlicense" = "1.2.0"
```

- **The backend is spelled out** (`aqua:`, `github:`, `npm:`, `core:`), so the trust path for each tool is pinned and
  can't drift if mise's registry defaults change.
- **The version is exact.** Renovate bumps it, and nobody edits a range.
- **`mise.lock` records per-platform sha256 checksums** for every pin, plus cosign, SLSA or GitHub-attestation
  provenance wherever the publisher provides it. mise verifies them on every install, and all verification is on by
  default.

Every tool is a **prebuilt release binary**, except markdownlint-cli2. It's an npm package with no standalone binary, so
mise's built-in aube installs it from the npm registry, and it runs on the bun pinned alongside it. Its shim calls
`node`, so `prose.sh` puts a `node` wrapper that execs bun first on its own PATH; no Node.js is installed. The prose
formatter needs no package at all: it's `bun fmt`, built into bun and compatible with Prettier.

The full, current list of pins is on the [Tool pins](../reference/tool-pins.md) reference page, generated from
`config.toml` itself.

## Lazy tools

Most pins carry `lazy = true` with `lazy_bins`. mise doesn't install a lazy tool when the config loads. It waits until
something actually runs the named binary. A Python docs repo never downloads golangci-lint or terraform, and a fresh CI
runner for a Markdown repo only fetches the prose and workflow linters.

The always-installed core is small: bun (the prose formatter and markdownlint's runtime), markdownlint-cli2, addlicense,
shellcheck, actionlint and zizmor.

## Supply-chain guards

`config.toml` sets `[settings]` that apply to every consumer:

```toml
[settings]
lockfile = true
locked = false
minimum_release_age = "3d"
```

- **`lockfile = true`**: installs resolve against `mise.lock` and verify its checksums.
- **`minimum_release_age = "3d"`**: a release must be at least three days old before mise resolves it. mise forwards
  this into npm's transitive resolution (`--min-release-age`), so even markdownlint-cli2's transitive dependencies can't
  pull a release younger than the cooldown. Renovate applies the same three-day `minimumReleaseAge` to the pins
  themselves, surfaced as the `renovate/stability-days` check.
- **`minimum_release_age_excludes`** exempts our own first-party CLIs (`github:bitwise-media-group/dotty`, `evolve`,
  `patchy`), so a release we cut rolls out at once, and `core:go`, so toolchain security releases land promptly. mise
  has no org-wide wildcard, so each first-party tool is listed by its full backend ID. Consumers can append entries,
  since list settings merge.

## Language runtimes are per-repo

The library deliberately **doesn't** pin a repo's language runtime. Each repo tracks its own version at its own cadence,
and its own Renovate bumps it.

**Go repos** pin `go` and `go:golang.org/x/vuln/cmd/govulncheck` in their root `[tools]`. govulncheck publishes no
binaries and must be compiled by the repo's own Go, which is why it rides with the `go` pin rather than the shared
config. mise keys a `go:` install by the tool's version alone, so after bumping `go` on a machine that already has
govulncheck, rebuild it once:

```sh
mise install -f "go:golang.org/x/vuln/cmd/govulncheck"
```

golangci-lint, gotestsum and goreleaser stay shared, because they're prebuilt binaries not coupled to the repo's Go. A
repo whose Go outpaces the shared golangci-lint overrides that one pin.

**Node repos** pin `node` in their root `[tools]`; the library provides no `node`. The prose tools run on the shared bun
through a `node` wrapper scoped to `prose.sh`, so it never shadows the repo's own runtime. bun is always installed and
pnpm is a shared lazy pin; a repo can pin its own version of either.

**Python repos** pin nothing: `uv` provisions the interpreter from `.python-version` or `requires-python`. A repo that
wants a mise-managed Python adds `python` to its root `[tools]`.

**Swift repos** pin `swift` in their root `[tools]` (mise's `core:swift` backend installs the swift.org release).
`swift format`, `llvm-cov` and `llvm-profdata` ship inside that toolchain, so formatting and coverage follow the repo's
pin with nothing shared to override.

The library also carries lazy `core:go` and `core:python` pins as fallbacks. A repo's own root pin always takes
precedence over them.

## Tools that fetch data at runtime

**grype** downloads its vulnerability database on first use (about 200 MB, cached in `~/.cache/grype`), and
**kubescape** downloads its controls artifacts (cached in `~/.kubescape`). The first container or deploy lint on a
machine needs network. Neither scan ever contacts a Kubernetes cluster: the tasks point `KUBECONFIG` at nothing.

## Secrets with fnox

`fnox`, the secrets manager, is a shared lazy pin. A repo keeps its secrets in a committed `fnox.toml` (encrypted
values, or references into a vault) and runs the commands that need them through `fnox exec`, on the same fnox version
locally and in CI. A repo without a `fnox.toml` never calls fnox, so it never downloads it.

To hand a repo-local task its secrets, wrap the command in `fnox exec`:

```toml
[tasks.deploy]
run = "fnox exec -- ./scripts/deploy.sh"
```

The terraform archetype already does this: its `tf-run.sh` wrapper runs every state-touching command through `fnox exec`
when the module directory carries a `fnox.toml` (see
[Variables and secrets](../archetypes/terraform.md#variables-and-secrets)).

A secret fnox can't resolve, such as in a CI job without vault access, only warns by default and the command still runs.
Set `if_missing = "error"` in `fnox.toml` to make it fail instead, or `FNOX_IF_MISSING` to change it for one job. Plain,
non-secret variables need no tool at all: put them in `mise.toml [env]`.
