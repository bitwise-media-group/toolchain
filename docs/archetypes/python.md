# python

The python archetype is uv-native. It covers repos whose primary language is Python: a package or application (ruff,
pytest, `uv build`), a Zensical documentation site (the org site, podcast-workflow, and this site), or both.

```toml
# mise.toml
[task_config]
includes = [".mise/common/tasks.toml", ".mise/archetypes/python/tasks.toml"]
```

```makefile
# Makefile
include .mise/archetypes/python/include.mk
```

## No Python pin needed

The shared `uv` pin provisions everything:

- **The interpreter**, from the repo's `.python-version` or `requires-python`.
- **The project environment**, from `pyproject.toml` and `uv.lock`.

A repo that wants a mise-managed Python adds `python = "…"` to its root `[tools]`.

ruff, pytest and pytest-cov come from the **project's own dev dependencies**, so the repo controls their versions. A
project without them, such as a docs-only site, skips those passes with a message rather than failing.

## Tasks

| Task    | What it does                                                                                |
| ------- | ------------------------------------------------------------------------------------------- |
| `fmt`   | License headers **first**, then `ruff format` and `ruff check --fix`, then prose format.    |
| `lint`  | license check, `ruff check` and `ruff format --check`, containers, shell, workflows, prose. |
| `test`  | pytest with a JUnit report (and Cobertura coverage when pytest-cov is installed).           |
| `build` | `uv build` and/or `zensical build`, depending on what the project declares.                 |
| `ci`    | `lint`, `test`, `build`.                                                                    |
| `pr`    | `fmt`, `lint`, `test`, `build`, `commit`.                                                   |

Every Python task depends on a hidden `sync` task (`uv sync`), so the environment is always current. `docs-build` and
`serve` come from [common](common.md), like every other repo's.

!!! info "Why license runs first here"

    The other archetypes inject license headers last. Here it runs first because addlicense inserts the header with one
    blank line after it, and ruff format wants two before a top-level definition. Running ruff after addlicense lets it
    fix the spacing.

### What `build` builds

`build` looks at the project and builds whatever it declares:

- **`uv build`** (sdist and wheel into `dist/`) when `pyproject.toml` has a `[build-system]` table;
- **`zensical build`** (the site into `site/`) when a `zensical.toml` is present;
- both, if both apply, or neither, with a message.

A docs-only site has a `pyproject.toml` with `zensical` as a dependency and no `[build-system]`, so `build` is just the
site build. That's the reason to pick this archetype for one: common alone gives it `docs-build` and `serve`, but no
`build`, so CI would never build the site.

### What `test` writes

- `coverage/junit.xml`: always, when pytest is installed.
- `coverage/coverage.xml`: Cobertura, when pytest-cov is installed (`--cov --cov-report=xml`).
- `coverage/.coverage`: the raw coverage data file.

A suite that collects no tests (pytest exit code 5) passes with a message instead of failing.

## A docs-only site

The minimal docs site looks like this:

```text
my-site/
├── .mise/              # the toolchain
├── docs/index.md
├── overrides/          # optional theme overrides
├── pyproject.toml      # dependencies = ["zensical>=…"], no [build-system]
├── uv.lock
├── zensical.toml
├── mise.toml           # common + python
└── Makefile            # include .mise/archetypes/python/include.mk
```

Add `site/` and `.venv/` to `.gitignore`, and `site/**` to `.licenseignore`. The reusable release workflow publishes the
site to GitHub Pages on each release whenever a `zensical.toml` sits at the repo root.

## Source

??? abstract "archetypes/python/tasks.toml"

    ```toml
    --8<-- "archetypes/python/tasks.toml"
    ```

??? abstract "archetypes/python/scripts/build.sh"

    ```sh
    --8<-- "archetypes/python/scripts/build.sh"
    ```

??? abstract "archetypes/python/scripts/test.sh"

    ```sh
    --8<-- "archetypes/python/scripts/test.sh"
    ```
