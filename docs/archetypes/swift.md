# swift

The swift archetype is for SwiftPM packages and CLIs: a repo with a `Package.swift` at its root. It formats, lints,
tests, builds and releases the package with the toolchain the repo pins. Xcode projects (`xcodebuild`) are out of scope.

```toml
# mise.toml
[tools]
swift = "6.4.1"

[vars]
swift_product = "mytool"

[task_config]
includes = [".mise/common/tasks.toml", ".mise/archetypes/swift/tasks.toml"]
```

```makefile
# Makefile
include .mise/archetypes/swift/include.mk
```

## Required pins

The library doesn't pin Swift, so each repo tracks its own toolchain at its own cadence:

- **`swift`**: the repo's Swift toolchain, installed from swift.org by mise's `core:swift` backend.

`swift format`, `llvm-cov` and `llvm-profdata` ship inside that toolchain, so formatting and coverage follow the repo's
pin with no shared pins of their own. goreleaser and syft come from the shared pins.

On macOS the swift.org toolchain still takes the SDK, and XCTest, from Xcode or the Command Line Tools, so one of those
must be installed. Swift Testing ships with the toolchain itself.

## Tasks

| Task       | What it does                                                                                          |
| ---------- | ----------------------------------------------------------------------------------------------------- |
| `fmt`      | `swift format format --in-place`, then prose format, then license headers.                            |
| `lint`     | license check, `swift format lint --strict`, containers, shell, workflows, prose.                     |
| `test`     | `swift test --enable-code-coverage`, writing JUnit reports and `coverage/lcov.info`.                  |
| `build`    | `swift build -c release`, for every product or the one `swift_product` names.                         |
| `ci`       | `lint`, `test`, `build`.                                                                              |
| `pr`       | `fmt`, `lint`, `test`, `build`, `commit`.                                                             |
| `update`   | `swift package update`, which rewrites `Package.resolved`.                                            |
| `snapshot` | `goreleaser release --snapshot --clean --skip=sign,notarize`.                                         |
| `release`  | `goreleaser release --clean`. Needs a `vX.Y.Z` tag and credentials.                                   |
| `resolve`  | Hidden. `swift package resolve`, honouring a committed `Package.resolved`. `test` and `build` run it. |

### Formatting

`fmt` and `lint` run `swift format` over the repo's Swift files, as git lists them: tracked files plus untracked files
that aren't ignored. Dependency checkouts under `.build/`, the `.mise` submodule and anything in `.gitignore` are never
touched. A `.swift-format` file at the repo root configures both passes. `lint` runs with `--strict`, so warnings fail
the gate too. A repo with no Swift files skips both passes with a message.

### Dependencies

`resolve` runs before `test` and `build`. When `Package.resolved` is committed, it resolves with
`--force-resolved-versions`, so an out-of-date lockfile fails the gate instead of drifting silently. A package that
doesn't commit `Package.resolved`, which is common for libraries, resolves normally. `make update` moves dependencies to
the latest versions `Package.swift` allows and rewrites `Package.resolved`.

### Coverage

`test` writes everything under `coverage/`, where the reusable CI workflow uploads from:

- **`coverage/junit.xml`**: XCTest results.
- **`coverage/junit-swift-testing.xml`**: Swift Testing results, which SwiftPM writes beside the XCTest report.
- **`coverage/lcov.info`**: `llvm-cov export -format=lcov` over the test bundle, excluding `.build/` and `Tests/`.
  Codecov ingests it directly.

Extra `swift test` flags for one run go in `SWIFT_TEST_FLAGS`:

```sh
make test SWIFT_TEST_FLAGS="--sanitize=thread --filter ParserTests"
```

A package without a `Tests/` directory skips `test` with a message.

### Build

`build` is a release build. With `swift_product` empty it builds every product; set the knob, or `SWIFT_PRODUCT` for one
run, to build just one. The task prints the directory the binaries landed in.

```sh
make build SWIFT_PRODUCT=mytool
```

There's no version stamping. Swift has no equivalent of Go's `-ldflags -X`, so a repo that wants its version in the
binary generates a source file in a repo-local task and runs it before `build` (see
[Extending & overriding](../concepts/extending.md#redefine-an-archetype-task)).

### Releases

GoReleaser OSS has no Swift builder, so the archetype ships a shim, `scripts/goreleaser-build.sh`, that a repo's
`.goreleaser.yaml` sets as the go builder's `tool`. GoReleaser runs it once per target with `GOOS` and `GOARCH` set. The
shim maps the pair to a Swift target, runs `swift build -c release --product <product>`, and copies the binary to where
GoReleaser expects it. Go-only flags such as `-ldflags` are ignored.

```yaml
# .goreleaser.yaml
version: 2
builds:
  - builder: go
    tool: .mise/archetypes/swift/scripts/goreleaser-build.sh
    no_main_check: true # there's no Go main package to find
    binary: mytool
    env: [SWIFT_PRODUCT=mytool]
    goos: [darwin]
    goarch: [arm64, amd64]
```

The product comes from `SWIFT_PRODUCT` in the build's `env`, falling back to the `swift_product` knob, so a repo that
sets the knob can drop the `env` line. Each build entry produces one product; a package that releases several products
lists one build per product.

| `GOOS`/`GOARCH` | Swift target                                              |
| --------------- | --------------------------------------------------------- |
| `darwin/arm64`  | `--triple arm64-apple-macosx`                             |
| `darwin/amd64`  | `--triple x86_64-apple-macosx`                            |
| `linux/amd64`   | `--swift-sdk x86_64-swift-linux-musl` (Static Linux SDK)  |
| `linux/arm64`   | `--swift-sdk aarch64-swift-linux-musl` (Static Linux SDK) |

The Linux targets build fully static binaries with the
[Static Linux SDK](https://www.swift.org/documentation/articles/static-linux-getting-started.html), which must be
installed (`swift sdk install …`) for the same Swift version the repo pins. They work from a macOS or a Linux host. Any
other pair fails with an error.

`snapshot` skips the same two steps as the go archetype's:

- **`sign`**: cosign keyless signing needs the GitHub Actions OIDC token, so it only works in the release workflow.
- **`notarize`**: a repo with a `notarize.macos` block enables it whenever `MACOS_SIGN_P12` is exported, and a developer
  who has the org's signing material in their shell shouldn't Developer ID-sign and notarize a throwaway snapshot by
  accident.

Real releases run in CI through the reusable release workflow, not through `make release`.

## Housekeeping

Add `.build/` and `.swiftpm/` to `.gitignore` (`swift package init` does this for you), along with `coverage/` and
`dist/`. The license and prose tasks already skip both directories.

## Knobs

| Knob            | Default       | Env override    | Meaning                                                             |
| --------------- | ------------- | --------------- | ------------------------------------------------------------------- |
| `swift_product` | every product | `SWIFT_PRODUCT` | Product `build` builds, and the GoReleaser shim's fallback product. |

Per-run only: `SWIFT_TEST_FLAGS`.

## Source

??? abstract "archetypes/swift/tasks.toml"

    ```toml
    --8<-- "archetypes/swift/tasks.toml"
    ```

??? abstract "archetypes/swift/scripts/format.sh"

    ```sh
    --8<-- "archetypes/swift/scripts/format.sh"
    ```

??? abstract "archetypes/swift/scripts/test.sh"

    ```sh
    --8<-- "archetypes/swift/scripts/test.sh"
    ```

??? abstract "archetypes/swift/scripts/build.sh"

    ```sh
    --8<-- "archetypes/swift/scripts/build.sh"
    ```

??? abstract "archetypes/swift/scripts/goreleaser-build.sh"

    ```sh
    --8<-- "archetypes/swift/scripts/goreleaser-build.sh"
    ```
