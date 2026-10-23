# Migrating from v2

v2 of the library shipped one task file per repo type (`.mise/tasks/<archetype>.toml`) and a single make shim
(`.mise/mise.mk`). v3 splits that into `common/` plus one language archetype, and moves language runtimes out of the
shared pins.

## Steps

1. **Move the runtime pins into the root `mise.toml [tools]`.** A Go repo adds `go` and
   `"go:golang.org/x/vuln/cmd/govulncheck"`, and a Node repo adds `node`. Python repos pin nothing.

2. **Replace the include.** Swap `includes = [".mise/tasks/<archetype>.toml"]` for
   `includes = [".mise/common/tasks.toml", ".mise/archetypes/<lang>/tasks.toml"]`, using the
   [mapping below](#archetype-mapping).

3. **Replace the make include.** Swap `include .mise/mise.mk` for `include .mise/archetypes/<lang>/include.mk`, or
   `include .mise/common/include.mk` for a common-only repo.

4. **Node repos: prepare for the license tasks.** They now run in the node archetype. Add `dist/**`, and anything else
   generated, to `.licenseignore`, and make sure a `typecheck` script exists in `package.json`.

5. **Run `make lint` once and address zizmor.** Workflow lint now includes zizmor. Fix its findings, or accept them
   inline (`# zizmor: ignore[audit-name]`) or in a `zizmor.yml`.

## Archetype mapping

| v2 task file   | v3 archetype                                       |
| -------------- | -------------------------------------------------- |
| `go-cli`       | `go`                                               |
| `node-lib`     | `node`                                             |
| `node-action`  | `node`, plus `node_install_flags = ""` in `[vars]` |
| `docs-site`    | `python`                                           |
| `markdown-lib` | common only (no second include)                    |

## Before and after

=== "v3"

    ```toml
    # mise.toml
    [tools]
    go = "1.27.2"
    "go:golang.org/x/vuln/cmd/govulncheck" = "1.8.0"

    [task_config]
    includes = [".mise/common/tasks.toml", ".mise/archetypes/go/tasks.toml"]
    ```

    ```makefile
    include .mise/archetypes/go/include.mk
    ```

=== "v2"

    ```toml
    # mise.toml
    [task_config]
    includes = [".mise/tasks/go-cli.toml"]
    ```

    ```makefile
    include .mise/mise.mk
    ```

## Coming from the Makefile-fragment era

v1 repos mounted the library at `make/` and included `make/<archetype>.mk` fragments, when the repo was still called
`make`. Remount the submodule at `.mise/` (`git mv make .mise`, then update `.gitmodules`), make sure mise is on `PATH`,
and follow the steps above using the v3 includes directly. Two habits from that era behave differently now:

- **Structural knobs live in `[vars]`.** The make variables once set before the include (`APP := …`) are now `[vars]`
  entries in the root `mise.toml`. The go scripts still accept the old spellings (`APP`, `APP_PKG`, …) from the
  environment, so `make build APP=x` keeps working.
- **Make prerequisites run before the forwarded task.** The old fragments ran appended targets after `commit`. Use a
  mise-side redefinition if you need different ordering (see [Extending & overriding](../concepts/extending.md)).
