# Tasks

Every task the library defines, by archetype. Hidden tasks don't appear in `make help` but run fine by name
(`mise run lint-prose`), and `mise tasks --hidden` lists them.

## Rollups

Each archetype redefines the rollups, replacing common's versions. Each step runs in sequence and stops at the first
failure.

| Rollup  | common                                                                 | go                                                                              | node                                                                              | python                                                                          | terraform                                                        |
| ------- | ---------------------------------------------------------------------- | ------------------------------------------------------------------------------- | --------------------------------------------------------------------------------- | ------------------------------------------------------------------------------- | ---------------------------------------------------------------- |
| `fmt`   | fmt-prose, license                                                     | go-fmt, fmt-prose, license                                                      | node-fmt, fmt-prose, license                                                      | license, py-fmt, fmt-prose                                                      | tf-fmt, fmt-prose                                                |
| `lint`  | license-check, lint-containers, lint-shell, lint-workflows, lint-prose | license-check, go-lint, lint-containers, lint-shell, lint-workflows, lint-prose | license-check, node-lint, lint-containers, lint-shell, lint-workflows, lint-prose | license-check, py-lint, lint-containers, lint-shell, lint-workflows, lint-prose | tf-lint, lint-containers, lint-shell, lint-workflows, lint-prose |
| `build` | —                                                                      | go-build                                                                        | node-build                                                                        | py-build                                                                        | —                                                                |
| `test`  | —                                                                      | go-test                                                                         | node-test                                                                         | py-test                                                                         | —                                                                |
| `docs`  | —                                                                      | — (repo-local)                                                                  | —                                                                                 | —                                                                               | tf-docs                                                          |
| `ci`    | lint                                                                   | lint, test, build                                                               | lint, build, test                                                                 | lint, test, build                                                               | lint, docs                                                       |
| `pr`    | fmt, lint                                                              | tidy, fmt, lint, test, build, commit                                            | fmt, lint, build, test, commit                                                    | fmt, lint, test, build, commit                                                  | fmt, lint, docs                                                  |

## common

Defined in `common/tasks.toml` and available in every repo.

| Task              | Hidden | Dir       | Runs                                                                     |
| ----------------- | ------ | --------- | ------------------------------------------------------------------------ |
| `commit`          |        | cwd       | `./commit.sh` if it exists and is executable.                            |
| `license`         |        | cwd       | `common/scripts/license.sh`: addlicense, inject mode.                    |
| `license-check`   | yes    | cwd       | `common/scripts/license.sh --check`.                                     |
| `fmt-prose`       | yes    | repo root | `common/scripts/prose.sh fmt`: prettier `--write`, markdownlint `--fix`. |
| `lint-prose`      | yes    | repo root | `common/scripts/prose.sh check`: markdownlint, prettier `--check`.       |
| `actionlint`      |        | repo root | `actionlint`.                                                            |
| `zizmor`          |        | repo root | `zizmor --min-severity {{vars.zizmor_min_severity}} .github/workflows`.  |
| `lint-workflows`  | yes    | repo root | `common/scripts/lint-workflows.sh`: actionlint, then zizmor.             |
| `lint-docker`     | yes    | repo root | `common/scripts/lint-docker.sh`: hadolint, grype on base images.         |
| `lint-helm`       | yes    | repo root | `common/scripts/lint-helm.sh`: helm lint, kubescape per chart.           |
| `lint-kustomize`  | yes    | repo root | `common/scripts/lint-kustomize.sh`: kubescape per kustomization.         |
| `lint-shell`      | yes    | repo root | `common/scripts/lint-shell.sh`: shellcheck over `scripts/`, `hack/`.     |
| `lint-containers` | yes    | —         | lint-docker, lint-helm, lint-kustomize.                                  |
| `docs-build`      |        | cwd       | `common/scripts/docs.sh build`: `uv sync`, then `zensical build`.        |
| `serve`           |        | cwd       | `common/scripts/docs.sh serve`: `uv sync`, then `zensical serve`.        |

## go

Defined in `archetypes/go/tasks.toml`. Every task runs in the invoking directory.

| Task       | Hidden | Runs                                                                         |
| ---------- | ------ | ---------------------------------------------------------------------------- |
| `tidy`     |        | `rm -f go.sum`, then `go mod tidy`.                                          |
| `go-fmt`   | yes    | `go fmt ./...`, then `golangci-lint run --fix`.                              |
| `go-lint`  | yes    | `scripts/lint.sh`: golangci-lint and govulncheck per GOOS.                   |
| `go-test`  | yes    | `scripts/test.sh`: gotestsum `-race`, coverage, compile-only per extra GOOS. |
| `go-build` | yes    | `scripts/build.sh`: `go build -trimpath` with version ldflags.               |
| `snapshot` |        | `goreleaser release --snapshot --clean --skip=sign,notarize`.                |
| `release`  |        | `goreleaser release --clean`.                                                |
| `fuzz`     |        | `scripts/fuzz.sh`: `go test -fuzz` on one package.                           |

## node

Defined in `archetypes/node/tasks.toml`. Every task runs in the invoking directory, and every leaf depends on
`node-install`.

| Task           | Hidden | Runs                                                                |
| -------------- | ------ | ------------------------------------------------------------------- |
| `node-install` | yes    | `scripts/pm.sh install`: the locked install, skipped while current. |
| `node-fmt`     | yes    | `pm.sh run-if-present check:fix format`.                            |
| `node-lint`    | yes    | `pm.sh run-if-present check`, then `pm.sh run typecheck`.           |
| `node-build`   | yes    | `pm.sh run build`.                                                  |
| `node-test`    | yes    | `pm.sh run-if-present test:coverage`.                               |

## python

Defined in `archetypes/python/tasks.toml`. Every task runs in the invoking directory, and every leaf depends on `sync`.

| Task       | Hidden | Runs                                                                  |
| ---------- | ------ | --------------------------------------------------------------------- |
| `sync`     | yes    | `uv sync`.                                                            |
| `py-fmt`   | yes    | `scripts/ruff.sh fmt`: `ruff format`, then `ruff check --fix`.        |
| `py-lint`  | yes    | `scripts/ruff.sh check`: `ruff check`, then `ruff format --check`.    |
| `py-test`  | yes    | `scripts/test.sh`: pytest with JUnit and optional Cobertura coverage. |
| `py-build` | yes    | `scripts/build.sh`: `uv build` and/or `zensical build`.               |

## terraform

Defined in `archetypes/terraform/tasks.toml`. Every task runs in the invoking directory.

| Task              | Hidden | Runs                                                      |
| ----------------- | ------ | --------------------------------------------------------- |
| `init`            |        | `tf-run.sh <binary> init`.                                |
| `init-no-backend` | yes    | `tf-run.sh <binary> init -backend=false -input=false`.    |
| `plan`            |        | `tf-run.sh <binary> plan -out=plan.tfplan`.               |
| `apply`           |        | `plan`, then `tf-run.sh <binary> apply plan.tfplan`.      |
| `tf-fmt`          | yes    | `<binary> fmt -recursive`.                                |
| `tf-lint`         | yes    | `init-no-backend`, `<binary> validate .`, `tflint`.       |
| `tf-docs`         | yes    | `terraform-docs .`, through `mise x` (installs it first). |

`<binary>` is the `terraform_binary` knob: `terraform` by default, or `tofu`.

## make targets

The make shim declares these names `.PHONY` and forwards them explicitly, so a same-named file or directory can't shadow
them:

| Shim                | Names                                                                                              |
| ------------------- | -------------------------------------------------------------------------------------------------- |
| `common/include.mk` | `lint build test e2e fmt ci pr commit license docs docs-build serve actionlint zizmor`, and `help` |
| go                  | adds `tidy snapshot release fuzz`                                                                  |
| python              | adds `sync`                                                                                        |
| terraform           | adds `init plan apply`                                                                             |
| node                | adds nothing                                                                                       |

Any other target, including every repo-local task, forwards through the `.DEFAULT` catch-all. An unknown name gets
mise's "no task" error.
