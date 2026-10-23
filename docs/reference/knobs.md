# Knobs

The toolchain has two tiers of configuration.

| Tier                           | Where                   | Examples                                               |
| ------------------------------ | ----------------------- | ------------------------------------------------------ |
| Structural (set once per repo) | root `mise.toml [vars]` | `app`, `goos`, `node_package_manager`, `grype_fail_on` |
| Per-invocation (runtime)       | environment variables   | `VERSION`, `GOOS`, `FUZZ`, `NODE_PACKAGE_MANAGER`      |

Structural knobs have defaults in the library's `config.toml [vars]`, and the repo's root `mise.toml [vars]` overrides
them. Task files reference them as `{{vars.name}}` and pass them to scripts as environment variables (usually
`TOOLCHAIN_*`, which keeps the plain spellings free for per-run overrides).

## Structural knobs

| Knob                   | Default                             | Archetype         | Meaning                                                                         |
| ---------------------- | ----------------------------------- | ----------------- | ------------------------------------------------------------------------------- |
| `license_holder`       | `BitWise Media Group Ltd`           | all but terraform | Copyright holder addlicense writes. Don't vary the spelling per repo.           |
| `app`                  | empty (repo directory name)         | go                | Output binary name.                                                             |
| `app_pkg`              | `.`                                 | go                | Main package to build.                                                          |
| `build_tags`           | empty                               | go                | Extra build tags, for example `withui`.                                         |
| `version_pkg`          | empty (`<module>/internal/version`) | go                | Package declaring `Version`, `Commit` and `BuildDate`.                          |
| `goos`                 | empty (host GOOS)                   | go                | Space-separated GOOS list that `lint` and `test` cover.                         |
| `node_package_manager` | empty (auto-detect)                 | node              | `npm`, `pnpm` or `bun`.                                                         |
| `node_install_flags`   | `--ignore-scripts`                  | node              | Flags for the locked install. An action repo sets `""`.                         |
| `npm_ci_flags`         | unset                               | node              | **Deprecated.** npm-only install flags; win over `node_install_flags` when set. |
| `terraform_binary`     | `terraform`                         | terraform         | `tofu` for OpenTofu (pin opentofu in root `[tools]` too).                       |
| `grype_fail_on`        | `high`                              | all               | Minimum grype severity that fails the Dockerfile base-image scan.               |
| `kubescape_severity`   | `high`                              | all               | Minimum kubescape severity that fails the helm and kustomize scans.             |
| `zizmor_min_severity`  | `low`                               | all               | Lowest zizmor finding severity that fails `lint`.                               |

Severity knobs take `low`, `medium`, `high` or `critical` (zizmor also accepts `unknown` and `informational`).

## Per-invocation variables

Make exports command-line variables to the forwarded `mise run`, so `make build VERSION=1.2.3` and
`VERSION=1.2.3 mise run build` are the same.

| Variable                                      | Archetype | Default                                            | Meaning                                             |
| --------------------------------------------- | --------- | -------------------------------------------------- | --------------------------------------------------- |
| `VERSION`                                     | go        | `git describe --tags --always --dirty`             | Version stamped into the binary.                    |
| `COMMIT`                                      | go        | `git rev-parse --short HEAD`                       | Commit stamped into the binary.                     |
| `DATE`                                        | go        | current UTC time                                   | Build date stamped into the binary.                 |
| `LDFLAGS`                                     | go        | `-s -w -X …Version … -X …Commit … -X …BuildDate …` | Replaces the whole ldflags string.                  |
| `MODULE`                                      | go        | `go list -m`                                       | Module path used to derive `version_pkg`.           |
| `GOOS`                                        | go        | the `goos` knob                                    | GOOS list for one `lint` or `test` run.             |
| `FUZZ`                                        | go        | `.*` (the package's only fuzz test)                | Fuzz target name.                                   |
| `FUZZTIME`                                    | go        | `20s`                                              | Fuzz duration.                                      |
| `FUZZ_PKG`                                    | go        | `./...`                                            | Package to fuzz. Must name exactly one.             |
| `APP`, `APP_PKG`, `BUILD_TAGS`, `VERSION_PKG` | go        | the knob                                           | Per-run overrides of the structural knobs.          |
| `NODE_PACKAGE_MANAGER`                        | node      | the `node_package_manager` knob                    | Force a package manager for one run.                |
| `NODE_INSTALL_FLAGS`                          | node      | the `node_install_flags` knob                      | Install flags; set-but-empty forces a bare install. |
| `NPM_CI_FLAGS`                                | node      | —                                                  | **Deprecated.** npm-only install flags.             |
| `GH_TOKEN`                                    | all       | —                                                  | Enables zizmor's online-only audits when exported.  |

## The defaults, as shipped

This is the live `[vars]` section of `config.toml`, embedded when the site is built:

```toml
--8<-- "config.toml:vars"
```
