# Adopt the toolchain

Adoption takes three files: a submodule, a root `mise.toml`, and a one-line `Makefile`. This page walks through each
one, then covers the housekeeping a consuming repo needs.

## 1. Mount the submodule

Add the library once, mounted at `.mise/`:

```sh
git submodule add https://github.com/bitwise-media-group/toolchain.git .mise
```

The mount point matters. mise treats `.mise/config.toml` as one of its own config files, so mounting the library there
makes its `[settings]`, `[tools]` and `[vars]` load natively, with no symlinks or per-repo tool setup. Every path in the
task files (`{{config_root}}/.mise/common/scripts/…`) assumes this location too.

From then on, Renovate's `git-submodules` manager opens a pull request to bump `.mise` whenever a new `vX.Y.Z` tag is
cut (see [Releases & updates](../concepts/releases.md)).

## 2. Write the root `mise.toml`

The root `mise.toml` does four jobs:

1. **Pins the language runtime** in `[tools]`. The library never pins a repo's runtime.
2. **Includes the task files** in `[task_config]`: `common` first, then exactly one archetype.
3. **Sets structural knobs** in `[vars]`, such as the Go binary name.
4. **Holds repo-local tasks**, if the repo needs any.

=== "go"

    ```toml
    # mise.toml — a Go CLI (dotty, evolve, gh-claude)
    [tools]
    go = "1.27.2"
    "go:golang.org/x/vuln/cmd/govulncheck" = "1.8.0" # must be built by the repo's own Go

    [vars]
    app = "dotty"
    app_pkg = "./cmd"

    [task_config]
    includes = [".mise/common/tasks.toml", ".mise/archetypes/go/tasks.toml"]
    ```

=== "node"

    ```toml
    # mise.toml — a TypeScript library or GitHub Action
    [tools]
    node = "24.20.0"

    # [vars]
    # node_install_flags = ""   # an action repo that runs lifecycle scripts

    [task_config]
    includes = [".mise/common/tasks.toml", ".mise/archetypes/node/tasks.toml"]
    ```

=== "python"

    ```toml
    # mise.toml — a uv project or a Zensical docs site
    # no [tools]: uv provisions Python from .python-version / requires-python

    [task_config]
    includes = [".mise/common/tasks.toml", ".mise/archetypes/python/tasks.toml"]
    ```

=== "terraform"

    ```toml
    # mise.toml — a Terraform module or environment
    # no [tools] for terraform; an OpenTofu repo adds its opentofu pin here
    # and sets terraform_binary = "tofu" in [vars]

    [task_config]
    includes = [".mise/common/tasks.toml", ".mise/archetypes/terraform/tasks.toml"]
    ```

=== "common only"

    ```toml
    # mise.toml — a Markdown/YAML repo (github-workflows, skills, .github)
    [task_config]
    includes = [".mise/common/tasks.toml"]
    ```

!!! warning "Exactly one archetype"

    Archetypes don't stack. mise merges included task files whole-task, and the later include wins, so a second
    archetype would silently replace the first's `fmt`, `lint`, `build`, `test`, `ci` and `pr` rollups. A repo that
    needs a second language uses its primary archetype and adds tasks for the other one. See
    [Choosing an archetype](../archetypes/index.md).

## 3. Reduce the `Makefile` to one line

```makefile
# Makefile — the whole thing
include .mise/archetypes/go/include.mk
```

Use the include that matches the archetype: `.mise/archetypes/<lang>/include.mk`, or `.mise/common/include.mk` for a
common-only repo. Each archetype shim pulls in the common forwarder, which turns every `make <target>` into
`mise run <target>`.

You can still add make-side prerequisites under the include:

```makefile
include .mise/archetypes/go/include.mk

# regenerate the CLI reference before the full local gate
pr: docs
```

## 4. Trust the config

mise refuses to run tasks from a config file it hasn't been told to trust. Run this once per clone:

```sh
mise trust --all
```

CI trusts the workspace automatically. Then list what the repo exposes:

```sh
make help      # or: mise tasks
```

## 5. Housekeeping

**`.gitignore`.** Keep the outputs the archetypes write out of git:

```gitignore
# every archetype's test task
coverage/
# node
node_modules/
# python, and any repo with a zensical docs site
.venv/
site/
# goreleaser, uv build
dist/
```

**`.licenseignore`.** The [license tasks](../reference/lint.md#license-headers) already skip `node_modules/`, `.mise/`,
`.claude/`, `.venv/`, `coverage/`, `pnpm-lock.yaml` and `commit.sh`. List anything else that's generated, one pattern
per line. A node action repo, for example, lists `dist/**` because its committed bundle must stay byte-identical to the
build output.

**Prose and workflow config.** You need none. Prettier, markdownlint, actionlint and zizmor read the library's house
defaults from `.mise/`. Commit your own `.prettierrc.yaml`, `.prettierignore` or `.markdownlint-cli2.yaml` only if you
want to override that file wholesale.

**CI.** Call the reusable workflow from `bitwise-media-group/github-workflows`. It discovers which of `lint`, `build`
and `test` your repo defines and runs only those. See [The CI contract](../concepts/contract.md).

!!! danger "Never re-lock in a consumer"

    Don't run `mise lock` or `mise upgrade` in a consuming repo. The lockfile for the shared pins lives inside the
    submodule, so a consumer-side re-lock writes into `.mise/` and leaves you with a dirty submodule. Shared pins change
    here, in this repo, and reach you through a submodule bump.

## Migrating an older repo

A repo on the v2 layout (`.mise/tasks/<archetype>.toml` plus `include .mise/mise.mk`) has a short path forward. See
[Migrating from v2](../reference/migrating.md).
