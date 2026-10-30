# Working on the toolchain

This page is for changing the library itself: adding a task, fixing a script, bumping a pin, or editing this site.

## Repository layout

```text
toolchain/                    # this repo == the consumer's .mise/ directory
├── config.toml               # shared config: [settings], [tools] pins, [vars] knob
│                             #   defaults — NO tasks; consumers load it natively as
│                             #   .mise/config.toml
├── mise.lock                 # per-platform sha256 + provenance for every pin
├── .prettierrc.yaml          # house prose defaults, read from .mise/ by every
├── .prettierignore           #   consumer that does not commit its own copy
├── .markdownlint-cli2.yaml
├── common/                   # what every repo gets, whatever its language
│   ├── tasks.toml            #   commit, license, prose fmt/lint, actionlint + zizmor,
│   │                         #   container/helm/kustomize/shell lint, and the
│   │                         #   fmt/lint/ci/pr rollups for a common-only repo
│   ├── include.mk            #   the whole make surface: thin forwarders to mise
│   └── scripts/              #   the shell behind the tasks (shellcheck-clean)
├── archetypes/               # exactly ONE per repo, included after common
│   ├── go/                   #   build/test/lint/fuzz/release + zensical docs
│   ├── node/                 #   package.json-script contract (npm/pnpm/bun)
│   ├── python/               #   uv-native: ruff + pytest + uv build + zensical
│   ├── swift/                #   SwiftPM: swift format + swift test + GoReleaser
│   └── terraform/            #   init/plan/apply + tf fmt/lint/docs
│       ├── tasks.toml        #   each archetype: its tasks + fmt/lint/ci/pr rollups
│       ├── include.mk        #   its make shim (pulls in common/include.mk)
│       └── scripts/          #   its task scripts
├── docs/, overrides/         # this documentation site (Zensical)
├── zensical.toml, pyproject.toml, uv.lock
├── mise.toml, Makefile       # the dogfood wiring (see below)
└── .mise/                    # symlinks back to the root entries, plus the real
                              #   mise.lock and its locks/ sidecars
```

## The inverted dogfood layout

This repo uses its own tasks, but it _is_ the library, so its layout is the inverse of a consumer's:

- `config.toml`, `common/` and `archetypes/` sit at the root.
- `.mise/` contains symlinks back to them (`archetypes`, `common`, `config.toml`), so mise loads `.mise/config.toml` and
  the tasks' `{{config_root}}/.mise/…` script paths resolve exactly as they do in a consumer.
- `mise.lock` is inverted the other way: the real file and its `locks/` dependency sidecars live in `.mise/`, and the
  root `mise.lock` is a symlink to it. mise places sidecars by the lockfile's physical directory, so only this layout
  records the same `locks/…` paths here and in consumers. Don't replace `.mise/locks/` with a symlink: mise refuses to
  read or write sidecars through one.
- The root `mise.toml` includes `common/tasks.toml` and `archetypes/python/tasks.toml` directly, without the `.mise/`
  prefix. The python archetype builds this site, so `make build` is `zensical build` and CI catches a broken page.
- The Makefile includes `archetypes/python/include.mk` and adds `lint: lint-scripts`, a make-side prerequisite that
  shellchecks the library's own scripts. (The consumer-facing `lint-shell` pass only sweeps a repo's root `scripts/` and
  `hack/`.)

Everything at the root also ships to every consumer inside `.mise/`. That's harmless for this site's files (`docs/`,
`overrides/`, `zensical.toml`, `pyproject.toml`, `uv.lock`): nothing in a consumer reads them. But it rules out anything
mise would pick up from a `.mise/` directory, such as a `tasks/` folder (mise treats `.mise/tasks/` as file tasks) or a
`conf.d/`.

## Local checks

```sh
mise trust --all
make lint     # license, ruff (skipped), containers, shell, workflows, prose + lint-scripts
make build    # builds this site
make serve    # live preview at http://localhost:8002/toolchain/
make pr       # the whole gate
```

## Adding or changing a task

- **Shared by every repo?** Put it in `common/tasks.toml`. If it's a lint pass, make it runtime-detected (no-op when the
  repo has none of the files) and wire it into the `lint` rollup of common **and every archetype**, since the archetypes
  replace common's rollups whole-task.
- **Language-specific?** Put it in that archetype's `tasks.toml`.
- **Longer than a one-liner?** Write a POSIX `sh` script under `scripts/`, keep it shellcheck-clean, and call it as
  `{{config_root}}/.mise/<path>/scripts/<name>.sh`. Pass structural knobs as environment variables on the task.
- **Only exists to be wired into a rollup?** Mark it `hide = true`.
- **New task name a consumer might shadow with a directory?** Add it to the archetype's `MISE_TASKS` in `include.mk`.
- **New knob?** Add a commented default to `config.toml [vars]`, inside the `--8<--` markers, and document it on the
  [Knobs](knobs.md) page.
- **Never stub.** If an archetype has no real work for a canonical task, don't define it. CI discovers what exists.

Then update the relevant pages here. The [Tasks](tasks.md) reference and the archetype pages are hand-written, but the
"Source" blocks and the pins and knob defaults are embedded from the live files.

## Bumping a pin by hand

Renovate normally does this. To do it yourself, edit `config.toml`, then re-lock:

```sh
GITHUB_TOKEN="$(gh auth token)" mise lock
```

Unauthenticated GitHub API calls can silently drop lockfile entries, so set the token first. mise writes through the
root `mise.lock` symlink into `.mise/mise.lock` and keeps the npm tools' dependency sidecars in `.mise/locks/`; commit
both.

## Commit messages

Commits follow [Conventional Commits](https://www.conventionalcommits.org/); release-please derives the version and
changelog from them. See [Releases & updates](../concepts/releases.md#versioning-policy) for which type to use.

## Editing this site

The site is Zensical with Material, themed in the parent BitWise Media Group palette.

| Path                         | What it is                                                                       |
| ---------------------------- | -------------------------------------------------------------------------------- |
| `zensical.toml`              | Site config and navigation.                                                      |
| `docs/`                      | The pages. Reference pages embed live files with `--8<-- "path"` snippets.       |
| `docs/stylesheets/extra.css` | The terracotta theme (`--bw-*` tokens shared with the org site) and the landing. |
| `overrides/home.html`        | The landing page.                                                                |
| `overrides/partials/`        | The header and drawer, with the logo-mark lockup.                                |

Snippet paths resolve against the repo root as well as `docs/`, so a page can embed any library file:

````markdown
```toml
;--8<-- "archetypes/go/tasks.toml"
```
````

To embed part of a file, wrap that part in named start and end section markers and reference it as `"file:name"`.
`config.toml` does this for `[tools]` and `[vars]`; copy the marker comments from there. (Snippets strips any line
containing a marker, even in prose, which is why they aren't spelled out on this page.)

Admonitions (`!!! note`) need a four-space-indented body, which the house markdownlint config reads as an indented code
block. `docs/.markdownlint.yaml` turns that rule off for the site's pages only.

A release publishes the site to GitHub Pages through the reusable release workflow's docs job, which runs whenever a
`zensical.toml` sits at the repo root.
