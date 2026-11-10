# containers

The containers archetype is for repos whose products are OCI artifacts published with
[patchy](https://oss.bitwisemedia.uk/patchy/supply-chain/). That covers a mirror store of vendored upstream charts and
images (`patchy mirror`, as in flux-containers), first-party images and Flux manifest artifacts (`patchy build`, as in
flux-manifests and patchy-app-manifests), or both. Most of these repos also carry a documentation site, and `build`
builds it.

```toml
# mise.toml — no [tools]: every pipeline tool is a shared pin
[task_config]
includes = [".mise/common/tasks.toml", ".mise/archetypes/containers/tasks.toml"]
```

```makefile
# Makefile
include .mise/archetypes/containers/include.mk
```

patchy reads its own config, usually `patchy.yaml` at the repo root. It holds the registries, signing, scan defaults,
and the `mirror:` and `build:` blocks. See patchy's
[configuration](https://oss.bitwisemedia.uk/patchy/cli/#configuration) and
[supply chain guide](https://oss.bitwisemedia.uk/patchy/supply-chain/). Every pipeline tool is a shared lazy pin, so a
repo on this archetype pins nothing itself and only downloads what its tasks call:

| Tool                                      | Used for                                                |
| ----------------------------------------- | ------------------------------------------------------- |
| patchy                                    | every task below                                        |
| cosign                                    | signing (`publish`, `mirror-publish`), provenance       |
| osv-scanner, grype                        | image scans, whichever the patchy config enables        |
| kubescape                                 | configuration scans, and common's container lint        |
| buildx                                    | image builds                                            |
| crane                                     | registry logins (`crane auth login`) and inspection     |
| kustomize, kubeconform, yq, flux-operator | the [Flux validation helpers](#flux-validation-helpers) |

## Tasks

Every task runs from the repo root, because patchy finds its config there and resolves build paths against it.

| Task                | What it does                                                                                                        |
| ------------------- | ------------------------------------------------------------------------------------------------------------------- |
| `build`             | `patchy build --all --dry-run`: build and scan every build entry without contacting a registry. Then the docs site. |
| `publish`           | `patchy build`: build, scan, publish every tag, sign.                                                               |
| `update-allowlists` | `patchy build --update-allowlists`: rebuild, rescan and regenerate `security/allowlists/<name>.yaml`.               |
| `mirror-add`        | `patchy mirror add`: scaffold an entry from `URL` (and an optional `ENTRY` name).                                   |
| `mirror-check`      | `patchy mirror upgrade --check`: the update plan, without touching the tree.                                        |
| `mirror-upgrade`    | `patchy mirror upgrade`: move pins and regenerate everything derived.                                               |
| `mirror-validate`   | `patchy mirror validate`: regenerate and byte-compare, verify provenance, scan, lint.                               |
| `mirror-lint`       | `patchy mirror validate --only lint`: manifests and CVE allowlists.                                                 |
| `mirror-publish`    | `patchy mirror sync`: publish charts and images by digest, signed.                                                  |
| `fmt`               | Prose format, license headers. Nothing rewrites YAML.                                                               |
| `lint`              | License, containers, shell, workflows, prose.                                                                       |
| `ci`                | `lint`, `build`.                                                                                                    |
| `pr`                | `fmt`, `lint`, `build`, `commit`.                                                                                   |

`fmt` stops at prose and license headers on purpose. Vendored charts, rendered output, lock files and Flux manifests
must stay byte-identical to whatever generated or reviewed them.

`build` is the pull-request gate. It proves every artifact builds and passes its scans, with no push credentials. In a
mirror store with no `build:` entries, patchy reports that there is nothing to build and succeeds. Like every
archetype's, `build` then runs common's `docs-build`, which skips with a message when the repo has no `zensical.toml`.

No rollup runs a `mirror-*` task. `mirror-validate` pulls every upstream chart, and its lint stage checks allowlist
expiry against today's date. In `lint` or `ci`, an entry expiring anywhere in the store would fail every pull request. A
mirror store validates the entries a pull request changes, in its own workflow. See
[Running a store in CI](https://oss.bitwisemedia.uk/patchy/supply-chain/mirror/#running-a-store-in-ci).

## Selecting entries

Selection comes from the environment, the same way through make and mise:

| Variable   | Tasks                                | Meaning                                                                       |
| ---------- | ------------------------------------ | ----------------------------------------------------------------------------- |
| `ENTRY`    | all but `mirror-add`                 | entry names, space-separated. Unset means every entry (`--all`).              |
| `ENTRY`    | `mirror-add`                         | the new entry's name (default: the URL's last path segment)                   |
| `URL`      | `mirror-add`                         | the upstream: an `https://` helm repo, an `oci://` chart repo, or an artifact |
| `REGISTRY` | `build`, `publish`, `mirror-publish` | registry names, space-separated. Unset means every registry.                  |

Flags for patchy go after `--` on `mise run` and are appended to the command:

```sh
make mirror-validate ENTRY="cert-manager dex"
make mirror-add URL=https://charts.dexidp.io
mise run mirror-validate -- -o markdown > summary.md   # task headers go to stderr
mise run mirror-upgrade -- --group flux --to 0.57.0    # a lockstep group replaces --all
REGISTRY=ghcr mise run publish -- -o markdown >> "$GITHUB_STEP_SUMMARY"
```

## Variables for tag templates

Before `build`, `publish` and `update-allowlists` run, three variables are derived from git when they aren't already
set. That way one set of tag templates expands the same way on a workstation and in CI, and a CI job that exports its
own value wins:

| Variable            | Default                                                                                       |
| ------------------- | --------------------------------------------------------------------------------------------- |
| `GIT_COMMIT`        | the HEAD commit (templates take `${GIT_COMMIT:0:7}`)                                          |
| `SOURCE_DATE_EPOCH` | the HEAD commit's time: reproducible buildx output, and `${PATCHY_TIMESTAMP}` derives from it |
| `VERSION`           | `.release-please-manifest.json`'s root version, else the newest `vX.Y.Z` tag, else `0.0.0`    |

The release-please manifest is read first because it is in the tree, so it works in a shallow CI checkout that fetched
no tags. In a release-please repo it holds the last release, which makes a monotonic base for edge builds. At a release
commit, it holds the version being released.

```yaml
# patchy.yaml
build:
  tags:
    - "${VERSION}-${CHANNEL:-edge}.${PATCHY_TIMESTAMP}.g${GIT_COMMIT:0:7}"
    - "sha-${GIT_COMMIT}"
  manifests:
    - name: platform
      repository: manifests/platform
      path: deploy
      source: "https://github.com/bitwise-media-group/flux-manifests"
      revision: "sha1:${GIT_COMMIT}"
```

Because the timestamp is the commit's own time, rebuilding a commit yields the same tags. A deterministic artifact
(every Flux manifests artifact, and a buildx image whose build is reproducible) yields the same digest too, so a re-run
of `publish` reports `skipped-current`.

## Flux validation helpers

A repo that publishes Flux trees usually renders them with sample inputs and validates the result. That harness is
repo-specific, so the archetype defines no `test`. It does ship the two halves every such harness shares, as scripts a
repo calls from its own:

```sh
.mise/archetypes/containers/scripts/flux-substitute.sh <in> <out>   # postBuild substitution, from the environment
.mise/archetypes/containers/scripts/flux-substitute.sh --self-test  # prove the null guard still trips
.mise/archetypes/containers/scripts/kubeconform.sh <file>...        # kubeconform, house schema catalog
```

**`flux-substitute.sh`** reproduces kustomize-controller's `postBuild` substitution closely enough that a render which
passes here also passes on a cluster:

- **Strict mode.** A bare `${VAR}` whose variable is unset fails. `${VAR:=default}` always passes.
- **The controller's round trip.** It parses, re-serializes, substitutes as text, then re-parses, so an empty value in a
  quoted scalar becomes null here just as it does on a cluster.
- **A null guard.** It fails if any `${VAR}`-bearing scalar became null.

Export the variables before calling it (`set -a; . tests/google.env; set +a`). Run `--self-test` once per harness, so
the guard can't stop working without anyone noticing.

**`kubeconform.sh`** runs `kubeconform -strict -summary` against the default Kubernetes catalog, the community Flux
catalog and the repo's vendored CRD schemas, named `<kind>-<group>-<version>.json` (`KUBECONFORM_SCHEMAS`, default
`tests/schemas`). It skips `CustomResourceDefinition` by default (`KUBECONFORM_SKIP`; set it empty to skip nothing).
Your own flags and files follow.

A repo wires its harness in through its own `tasks.toml`, included after the archetype. The reusable CI runs `test`
whenever a repo defines it, and the rollups take it in when the repo restates them:

```toml
# tasks.toml
[test]
description = "render + schema-validate the Flux trees"
dir = "{{config_root}}"
run = "./scripts/validate.sh"

[ci]
description = "the gates the reusable CI workflow runs"
run = [{ task = "lint" }, { task = "test" }, { task = "build" }]

[pr]
description = "full local gate before a pull request"
run = [{ task = "fmt" }, { task = "lint" }, { task = "test" }, { task = "build" }, { task = "commit" }]
```

## A docs site with generated pages

`build` reaches the site through the `docs-build` task, so a site whose pages embed generated content overrides
`docs-build` to generate it first. flux-containers renders its chart reference pages from the committed tree:

```toml
# tasks.toml
[docs-build]
description = "build the documentation site (chart references + zensical)"
dir = "{{config_root}}"
run = ["uv sync", "uv run --no-sync python scripts/chart_docs.py", "uv run --no-sync zensical build"]
```

## Image builds

Image entries build with `docker buildx`. The shared buildx pin links itself into `~/.docker/cli-plugins`. A
multi-platform OCI export needs a `docker-container` builder (`docker buildx create --use --driver docker-container`, or
`docker/setup-buildx-action` in GitHub Actions) or the containerd image store. A foreign architecture also needs QEMU
(`docker/setup-qemu-action`). Repos that only publish Flux manifests need no docker at all.

## In CI

The reusable CI workflow runs `lint` and `build`, plus `test` when the repo defines one. Publishing belongs to the
repo's own workflows, which set up mise, log in to each registry, and run a task:

```yaml
permissions:
  contents: read
  id-token: write # keyless signing
steps:
  - uses: actions/checkout@<sha>
    with: { submodules: true, persist-credentials: false }
  - uses: jdx/mise-action@<sha>
  # … log in to each registry host (docker login, or a cloud auth action) …
  - run: mise run publish -- -o markdown >> "$GITHUB_STEP_SUMMARY"
    env:
      CHANNEL: staging # edge by default in the templates above
```
