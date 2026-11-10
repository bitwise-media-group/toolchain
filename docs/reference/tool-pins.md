# Tool pins

The shared tools every consumer gets. Renovate keeps these current, so rather than a hand-maintained copy, this page
embeds the live `[tools]` section of `config.toml` at build time. The published site always matches the release it was
built from.

## What each tool does

| Tool              | Backend                                      | Used by                                                          | Lazy |
| ----------------- | -------------------------------------------- | ---------------------------------------------------------------- | ---- |
| go                | `core:go`                                    | fallback Go runtime (repos pin their own)                        | yes  |
| python            | `core:python`                                | fallback Python (uv provisions per repo)                         | yes  |
| markdownlint-cli2 | `npm:markdownlint-cli2`                      | `lint-prose`, `fmt-prose`                                        |      |
| bun               | `aqua:oven-sh/bun`                           | `bun fmt` and markdownlint's runtime; node archetype (bun repos) |      |
| addlicense        | `github:google/addlicense`                   | `license`, `license-check`                                       |      |
| shellcheck        | `aqua:koalaman/shellcheck`                   | `lint-shell`, actionlint's `run:` checks                         |      |
| actionlint        | `aqua:rhysd/actionlint`                      | `lint-workflows`, `actionlint`                                   |      |
| zizmor            | `aqua:zizmorcore/zizmor`                     | `lint-workflows`, `zizmor`                                       |      |
| grype             | `aqua:anchore/grype`                         | `lint-docker`; patchy image scans (containers)                   | yes  |
| syft              | `aqua:anchore/syft`                          | GoReleaser SBOMs (`snapshot`, `release`)                         | yes  |
| uv                | `aqua:astral-sh/uv`                          | python archetype, Zensical tasks                                 | yes  |
| golangci-lint     | `aqua:golangci/golangci-lint`                | `go-fmt`, `go-lint`                                              | yes  |
| goreleaser        | `aqua:goreleaser/goreleaser`                 | `snapshot`, `release` (go, swift)                                | yes  |
| gotestsum         | `aqua:gotestyourself/gotestsum`              | `go-test`                                                        | yes  |
| hadolint          | `aqua:hadolint/hadolint`                     | `lint-docker`                                                    | yes  |
| terraform         | `aqua:hashicorp/terraform`                   | terraform archetype                                              | yes  |
| helm              | `aqua:helm/helm`                             | `lint-helm`                                                      | yes  |
| fnox              | `aqua:jdx/fnox`                              | repo secrets via `fnox exec`; terraform's `tf-run.sh`            | yes  |
| kubescape         | `aqua:kubescape/kubescape`                   | `lint-helm`, `lint-kustomize`; patchy config scans (containers)  | yes  |
| pnpm              | `aqua:pnpm/pnpm`                             | node archetype (pnpm repos)                                      | yes  |
| cosign            | `aqua:sigstore/cosign`                       | GoReleaser signing; patchy signing and provenance (containers)   | yes  |
| buildx            | `aqua:docker/buildx`                         | patchy image builds (containers); linked into docker's plugins   |      |
| patchy            | `github:bitwise-media-group/patchy`          | containers archetype (`patchy mirror`, `patchy build`)           | yes  |
| osv-scanner       | `aqua:google/osv-scanner`                    | patchy image scans (containers)                                  | yes  |
| crane             | `aqua:google/go-containerregistry`           | registry logins and inspection (containers)                      | yes  |
| kustomize         | `aqua:kubernetes-sigs/kustomize`             | Flux validation harnesses (containers)                           | yes  |
| kubeconform       | `aqua:yannh/kubeconform`                     | `scripts/kubeconform.sh` (containers)                            | yes  |
| yq                | `aqua:mikefarah/yq`                          | `scripts/flux-substitute.sh` (containers)                        | yes  |
| flux-operator     | `github:controlplaneio-fluxcd/flux-operator` | ResourceSet renders in Flux harnesses (containers)               | yes  |
| terraform-docs    | `aqua:terraform-docs/terraform-docs`         | `tf-docs`                                                        | yes  |
| tflint            | `aqua:terraform-linters/tflint`              | `tf-lint`                                                        | yes  |

govulncheck isn't here: every Go repo pins `go:golang.org/x/vuln/cmd/govulncheck` next to its own `go`, because it must
be compiled by that Go.

## Current pins

```toml
--8<-- "config.toml:tools"
```

## Overriding a pin

A repo's root `mise.toml [tools]` beats the shared config. To run a newer golangci-lint than the fleet:

```toml
[tools]
"aqua:golangci/golangci-lint" = "2.15.0"
```

Use the same backend spelling as the shared pin, so the two entries refer to the same tool. With `lockfile = true` in
its root `[settings]`, the repo records that pin's checksums in its own `mise.lock`.
