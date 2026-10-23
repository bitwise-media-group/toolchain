# go

The go archetype is for Go CLI applications: dotty, evolve and gh-claude. It formats, lints, tests, builds and releases
a single binary. A Go repo with a docs site needs no second archetype: common's `docs-build` and `serve` are always
there.

```toml
# mise.toml
[tools]
go = "1.27.2"
"go:golang.org/x/vuln/cmd/govulncheck" = "1.8.0"

[vars]
app = "dotty"
app_pkg = "./cmd"

[task_config]
includes = [".mise/common/tasks.toml", ".mise/archetypes/go/tasks.toml"]
```

```makefile
# Makefile
include .mise/archetypes/go/include.mk
```

## Required pins

The library pins neither `go` nor govulncheck, so each repo tracks its own Go at its own cadence:

- **`go`**: the repo's Go toolchain.
- **`go:golang.org/x/vuln/cmd/govulncheck`**: govulncheck publishes no binaries and must be compiled by the same Go the
  repo builds with, so it rides with the `go` pin.

golangci-lint, gotestsum, goreleaser and syft come from the shared pins. If the repo's Go outpaces the shared
golangci-lint, override `"aqua:golangci/golangci-lint"` in the root `[tools]`.

## Tasks

| Task       | What it does                                                                                        |
| ---------- | --------------------------------------------------------------------------------------------------- |
| `fmt`      | `go fmt ./...` and `golangci-lint run --fix`, then prose format, then license headers.              |
| `lint`     | license check, golangci-lint + govulncheck per GOOS, containers, shell, workflows, prose.           |
| `test`     | gotestsum with `-race -covermode=atomic`, writing `coverage/coverage.out` and `coverage/junit.xml`. |
| `build`    | `CGO_ENABLED=0 go build -trimpath` with version metadata stamped in via `-ldflags`.                 |
| `ci`       | `lint`, `test`, `build`.                                                                            |
| `pr`       | `tidy`, `fmt`, `lint`, `test`, `build`, `commit`.                                                   |
| `tidy`     | Delete `go.sum`, then `go mod tidy`.                                                                |
| `fuzz`     | Fuzz one target (`FUZZ`, `FUZZTIME`, `FUZZ_PKG`).                                                   |
| `snapshot` | `goreleaser release --snapshot --clean --skip=sign,notarize`.                                       |
| `release`  | `goreleaser release --clean`. Needs a `vX.Y.Z` tag and credentials.                                 |

### Build metadata

`build` stamps three variables into the binary, at the same import path GoReleaser uses on tagged releases:

```text
-X <version_pkg>.Version=<git describe --tags --always --dirty>
-X <version_pkg>.Commit=<git rev-parse --short HEAD>
-X <version_pkg>.BuildDate=<UTC timestamp>
```

`version_pkg` defaults to `<module>/internal/version`. The output binary is named by `app`, defaulting to the repository
directory's name, and built from `app_pkg`, defaulting to `.`. Every value can be overridden per run:

```sh
make build VERSION=1.2.3
make build APP=dotty-dev BUILD_TAGS=withui
make build LDFLAGS="-s -w"   # replaces the whole ldflags string
```

### Multi-platform lint and test

Set `goos` to a space-separated GOOS list for a cross-platform CLI:

```toml
[vars]
goos = "linux darwin windows"
```

- **`lint`** runs golangci-lint and govulncheck once per entry, because both type-check the build for the GOOS they run
  under. A platform-specific file is only analysed when its platform is in the list. Every platform runs before the task
  exits, so one gate reports every platform's findings.
- **`test`** runs the full suite on the host's GOOS, plus a compile-only `go test -c` pass for every other entry, since
  cross-compiled test binaries can't execute. That still fails on a platform-specific test file that no longer builds.

Empty (the default) means the host's GOOS only. `GOOS` in the environment overrides the list per run:
`make test GOOS=windows`.

### Fuzzing

```sh
make fuzz FUZZ=FuzzParse FUZZTIME=1m FUZZ_PKG=./internal/parse
```

`go test -fuzz` accepts a single package only, so `FUZZ_PKG` must name one. With no `FUZZ`, the pattern matches every
fuzz test in the package, which only works when there's exactly one. Most repos redefine `fuzz` with their own default
target (see [Extending & overriding](../concepts/extending.md#redefine-an-archetype-task)).

### Releases

`snapshot` builds a local release (binaries, archives, SBOMs via syft) without publishing anything. It skips two steps
that would misfire locally:

- **`sign`**: cosign keyless signing needs the GitHub Actions OIDC token, so it only works in the release workflow.
- **`notarize`**: a repo with a `notarize.macos` block enables it whenever `MACOS_SIGN_P12` is exported, and a developer
  who has the org's signing material in their shell shouldn't Developer ID-sign and notarize a throwaway snapshot by
  accident.

Real releases run in CI through the reusable release workflow, not through `make release`.

### Docs

The archetype deliberately leaves `docs` to the repo, because regenerating a CLI reference is app-specific. A typical
repo-local task builds the binary, regenerates the reference, then builds the site with common's `docs-build`:

```toml
[tasks.docs]
description = "regenerate the CLI reference and build the docs site"
dir = "{{cwd}}"
run = [{ task = "build" }, "./dotty docs --out docs/cli --format markdown", { task = "docs-build" }]
```

```makefile
pr: docs
```

There's no `e2e` task. The reusable CI's e2e job is opt-in, and a repo that opts in defines its own.

## Knobs

| Knob          | Default                     | Env override  | Meaning                                           |
| ------------- | --------------------------- | ------------- | ------------------------------------------------- |
| `app`         | the repo directory's name   | `APP`         | Output binary name.                               |
| `app_pkg`     | `.`                         | `APP_PKG`     | Main package to build.                            |
| `build_tags`  | empty                       | `BUILD_TAGS`  | Extra build tags (for example `withui`).          |
| `version_pkg` | `<module>/internal/version` | `VERSION_PKG` | Package declaring `Version`/`Commit`/`BuildDate`. |
| `goos`        | the host's GOOS             | `GOOS`        | GOOS list that `lint` and `test` cover.           |

Per-run only: `VERSION`, `COMMIT`, `DATE`, `LDFLAGS`, `MODULE`, `FUZZ`, `FUZZTIME`, `FUZZ_PKG`.

## Source

??? abstract "archetypes/go/tasks.toml"

    ```toml
    --8<-- "archetypes/go/tasks.toml"
    ```

??? abstract "archetypes/go/scripts/build.sh"

    ```sh
    --8<-- "archetypes/go/scripts/build.sh"
    ```

??? abstract "archetypes/go/scripts/lint.sh"

    ```sh
    --8<-- "archetypes/go/scripts/lint.sh"
    ```

??? abstract "archetypes/go/scripts/test.sh"

    ```sh
    --8<-- "archetypes/go/scripts/test.sh"
    ```
