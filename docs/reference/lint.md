# Shared lint passes

`common/tasks.toml` defines the passes every archetype's `lint` carries. They need no per-repo config, and the
runtime-detected ones no-op silently in a repo that has none of the files they check, so every archetype includes them
unconditionally.

| Pass                                          | Checks                              | Runs when               | Fails at                |
| --------------------------------------------- | ----------------------------------- | ----------------------- | ----------------------- |
| [license](#license-headers)                   | SPDX headers on source files        | always (not terraform)  | any missing header      |
| [prose](#prose)                               | every `*.md`                        | always                  | any finding             |
| [workflows](#github-actions-workflows)        | `.github/workflows`                 | the directory exists    | zizmor `low` and up     |
| [docker](#containers-and-deploy-manifests)    | root `Dockerfile`, `Dockerfile.*`   | a Dockerfile exists     | grype `high` and up     |
| [helm](#containers-and-deploy-manifests)      | `helm/*/Chart.yaml`                 | a chart exists          | kubescape `high` and up |
| [kustomize](#containers-and-deploy-manifests) | `kustomization.yaml` directories    | a kustomization exists  | kubescape `high` and up |
| [shell](#shell-scripts)                       | `*.sh` under `scripts/` and `hack/` | either directory exists | any shellcheck finding  |

## License headers

`license` and `license-check` run addlicense with the MIT license and the `license_holder` knob, writing SPDX-only
headers (`-s=only`):

```text
# Copyright 2026 BitWise Media Group Ltd
# SPDX-License-Identifier: MIT
```

The house ignores always apply: `node_modules/**`, `.mise/**`, `.claude/**`, `.venv/**`, `coverage/**`,
`**/pnpm-lock.yaml` and `commit.sh`. A repo's `.licenseignore` adds to them, one pattern per non-empty line:

```text
dist/**
site/**
testdata/**
```

`make fmt` injects missing headers; `make lint` fails on them. The terraform archetype doesn't run these passes, because
addlicense would stamp `.tf` files.

## Prose

`fmt-prose` and `lint-prose` run the pinned prettier and markdownlint-cli2 over every `*.md`, from the repo root:

| Mode    | Steps                                               |
| ------- | --------------------------------------------------- |
| `fmt`   | `prettier --write`, then `markdownlint-cli2 --fix`. |
| `check` | `markdownlint-cli2`, then `prettier --check`.       |

Prettier honours `.gitignore` as well as the prettier ignore file.

### House defaults

The library's own config files are the house defaults. A consumer reads them from `.mise/` unless it commits its own
copy of a file, which then overrides that file **wholesale**:

| File                      | House setting                                                                                                                                                                      |
| ------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `.prettierrc.yaml`        | `proseWrap: always`, `printWidth: 120`.                                                                                                                                            |
| `.prettierignore`         | `CHANGELOG.md`, `node_modules/`, `.mise/`, `.venv/`, `.claude/`.                                                                                                                   |
| `.markdownlint-cli2.yaml` | All default rules; 120-column lines (tables exempt); sibling-only duplicate headings; fenced code blocks. Ignores `node_modules/`, `.mise/`, `.venv/`, `.claude/`, `CHANGELOG.md`. |

Patterns in the house ignore files are deliberately unanchored, because prettier and markdownlint resolve them against
the invoking repo, not against `.mise/`.

??? abstract ".markdownlint-cli2.yaml"

    ```yaml
    --8<-- ".markdownlint-cli2.yaml"
    ```

## GitHub Actions workflows

`lint-workflows` lints `.github/workflows` with two tools, and no-ops when the directory doesn't exist:

1. **actionlint**: syntax, expressions, and shellcheck over embedded `run:` scripts.
2. **zizmor**: security audits for script injection, unpinned actions, excessive permissions and dangerous triggers.

zizmor fails the gate at **low** severity and up (`zizmor_min_severity`). Silence an accepted finding inline, or in a
repo `zizmor.yml` (auto-loaded from the repo root or `.github/`):

```yaml
on: # zizmor: ignore[dangerous-triggers]
  pull_request_target:
```

zizmor's online-only audits run only when `GH_TOKEN` is exported; otherwise it prints a notice and skips them. To run
either tool alone, use `make actionlint` or `make zizmor`.

## Containers and deploy manifests

### Dockerfiles

`lint-docker` finds every root `Dockerfile` and `Dockerfile.*` and:

1. runs **hadolint** on each one. It fails on any warning by default.
2. runs **grype** against every **external base image** named in a `FROM` line, pulled straight from its registry
   (`registry:` scheme, so no Docker daemon and no build).

Base-image resolution is careful about multi-stage builds:

- `FROM` targets that name an earlier build stage (`AS alias`) or `scratch` are skipped, silently.
- Simple `ARG` defaults are resolved first: `ARG RUNTIME=static` then `FROM runtime-${RUNTIME}` resolves to the
  `runtime-static` alias.
- A ref that still contains an unresolved variable is reported and skipped, never guessed at.

grype runs with `--platform linux/amd64` (fleet images deploy to linux, and one platform keeps macOS and CI results
identical) and `--only-fixed`. Base images always carry won't-fix distro CVEs, so only a finding with an available fix,
meaning a newer base would fix it, is actionable enough to gate on.

### Helm charts

`lint-helm` finds every chart at `helm/*/Chart.yaml` and runs `helm lint`, then a **kubescape** misconfiguration scan.
kubescape renders the chart natively with its default values.

### Kustomizations

`lint-kustomize` finds every directory with a `kustomization.yaml` or `kustomization.yml` (pruning `.git`, `.mise`,
`.claude`, `node_modules`, `.venv` and `coverage`) and runs a kubescape scan, which builds the kustomization natively.
`kind: Component` directories are skipped with a note: they only build through an overlay, and the overlays that include
them still exercise their content.

### Silencing findings

| Scanner   | Repo-level config                                          |
| --------- | ---------------------------------------------------------- |
| hadolint  | `.hadolint.yaml`, or inline `# hadolint ignore=…` comments |
| grype     | `.grype.yaml` (auto-loaded from the repo root)             |
| kubescape | `.kubescape/exceptions.json` (passed as `--exceptions`)    |

### First run and isolation

The first scan on a machine downloads grype's vulnerability database (about 200 MB, cached in `~/.cache/grype`) and
kubescape's controls artifacts (cached in `~/.kubescape`), so it needs network.

The scans never contact a Kubernetes cluster. The tasks set `KUBECONFIG=/nonexistent`, because kubescape otherwise talks
to whatever cluster your kubeconfig names, and a lint of local files must never touch a live cluster.

## Shell scripts

`lint-shell` runs **shellcheck** over every `*.sh` under the repo's `scripts/` and `hack/` directories, recursively.
Starting from those two root directories keeps the library's own scripts in `.mise/` out of consumer runs.

!!! tip

    A comment that starts with the word "shellcheck" is parsed as a directive. Reword comments like
    `# shellcheck is happy here` so they don't begin with it.

## Source

??? abstract "common/scripts/prose.sh"

    ```sh
    --8<-- "common/scripts/prose.sh"
    ```

??? abstract "common/scripts/license.sh"

    ```sh
    --8<-- "common/scripts/license.sh"
    ```

??? abstract "common/scripts/lint-workflows.sh"

    ```sh
    --8<-- "common/scripts/lint-workflows.sh"
    ```

??? abstract "common/scripts/lint-docker.sh"

    ```sh
    --8<-- "common/scripts/lint-docker.sh"
    ```

??? abstract "common/scripts/lint-helm.sh"

    ```sh
    --8<-- "common/scripts/lint-helm.sh"
    ```

??? abstract "common/scripts/lint-kustomize.sh"

    ```sh
    --8<-- "common/scripts/lint-kustomize.sh"
    ```

??? abstract "common/scripts/lint-shell.sh"

    ```sh
    --8<-- "common/scripts/lint-shell.sh"
    ```
