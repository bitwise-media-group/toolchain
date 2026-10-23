# node

The node archetype covers Node and TypeScript repos: libraries such as `design-system`, and GitHub Actions such as
`ff-merge` and `setup-evolve`. It works with npm, pnpm or bun, and drives everything through the repo's own package.json
scripts.

```toml
# mise.toml
[tools]
node = "24.20.0"

[task_config]
includes = [".mise/common/tasks.toml", ".mise/archetypes/node/tasks.toml"]
```

```makefile
# Makefile
include .mise/archetypes/node/include.mk
```

The repo pins its own `node`. The library also pins `node`, but only as the runtime for prettier and markdownlint, and
the repo's root pin wins.

## The package.json-script contract

The archetype never calls biome, tsc or vitest itself. It runs the repo's package.json scripts, by ecosystem convention:

| Script          | Typically                          | Used by | Required? |
| --------------- | ---------------------------------- | ------- | --------- |
| `check`         | biome: lint and format check       | `lint`  | optional  |
| `check:fix`     | biome: auto-fix                    | `fmt`   | optional  |
| `format`        | a formatter pass beyond biome      | `fmt`   | optional  |
| `typecheck`     | `tsc --noEmit`                     | `lint`  | required  |
| `build`         | tsup, tsc or rollup                | `build` | required  |
| `test:coverage` | vitest with coverage → `coverage/` | `test`  | optional  |

Optional scripts run only when `package.json` defines them. A library with no tests still gets a `test` task that passes
trivially. This is the one place the library tolerates a task that may do nothing, because the script set is the repo's
declaration of what applies. biome owns the code, and prettier plus markdownlint (from common) own the Markdown.

## Tasks

| Task    | What it does                                                                                      |
| ------- | ------------------------------------------------------------------------------------------------- |
| `fmt`   | `check:fix` and `format` scripts (if defined), prose format, license headers.                     |
| `lint`  | license check, `check` script (if defined) then `typecheck`, containers, shell, workflows, prose. |
| `build` | The `build` script.                                                                               |
| `test`  | The `test:coverage` script, if defined.                                                           |
| `ci`    | `lint`, `build`, `test`.                                                                          |
| `pr`    | `fmt`, `lint`, `build`, `test`, `commit`.                                                         |

Every node task depends on a hidden `node-install` task, which installs exactly as locked and runs everything straight
from `node_modules`, never through `npx` or a global install.

The reusable CI fails an action PR if the committed `dist/` differs from a fresh build, so an action's `build` must be
reproducible. Such a repo lists `dist/**` in `.licenseignore` so the license pass doesn't stamp the bundle.

## Package managers

Every node task goes through `archetypes/node/scripts/pm.sh`, which picks the package manager in this order:

1. **`NODE_PACKAGE_MANAGER`** in the environment, else the **`node_package_manager`** var (`npm`, `pnpm` or `bun`).
   Empty, the default, means auto-detect. Any other value fails.
2. **The name in `package.json` `"packageManager"`**: `"pnpm@12.10.0"` means pnpm.
3. **The lockfile**: `package-lock.json` or `npm-shrinkwrap.json` means npm, `pnpm-lock.yaml` means pnpm, and `bun.lock`
   or `bun.lockb` means bun. Lockfiles from more than one manager fail with an error naming them. Set
   `node_package_manager` (or `"packageManager"`) to pick one.
4. **npm**.

pnpm and bun come from the shared lazy pins, so they're checksum-locked and installed the first time a task needs them.
CI needs no setup step. A repo may pin its own version in its root `[tools]` (`"aqua:pnpm/pnpm" = "…"`), and its pin
wins.

!!! note "pnpm never self-switches"

    pnpm normally downloads and switches to whatever version `"packageManager"` names, which would bypass the
    checksum-locked pin. `pm.sh` stops that (`pnpm_config_pm_on_fail=warn` for pnpm 11+, and
    `npm_config_manage_package_manager_versions=false` for pnpm 10), so a version mismatch is only reported as a
    warning.

### The locked install

| Manager | Command                                 |
| ------- | --------------------------------------- |
| npm     | `npm ci $flags --no-fund`               |
| pnpm    | `pnpm install --frozen-lockfile $flags` |
| bun     | `bun install --frozen-lockfile $flags`  |

`$flags` comes from the `node_install_flags` var, which defaults to `--ignore-scripts`: the safe choice for a library. A
GitHub Action repo that relies on lifecycle scripts sets `node_install_flags = ""` in its root `[vars]`.
`NODE_INSTALL_FLAGS` in the environment overrides it per run. It's checked as set-or-unset, so `NODE_INSTALL_FLAGS=`
forces a bare install.

The install is skipped while `node_modules/.toolchain-install`, a sentinel `pm.sh` touches after a successful install,
is newer than `package.json`, `pnpm-workspace.yaml` and every manager's lockfile.

!!! warning "Deprecated: `npm_ci_flags`"

    The older npm-only `npm_ci_flags` var and `NPM_CI_FLAGS` env still work for npm repos and win over
    `node_install_flags` when set. Both are ignored for pnpm and bun. Prefer the neutral knobs.

A repo needs no `.gitignore` or `.licenseignore` change for pnpm or bun: `node_modules/` is already ignored, and the
license tasks skip `pnpm-lock.yaml` by default. addlicense doesn't stamp the other lockfiles' formats.

## Knobs

| Knob                   | Default            | Env override           | Meaning                                |
| ---------------------- | ------------------ | ---------------------- | -------------------------------------- |
| `node_package_manager` | empty (detect)     | `NODE_PACKAGE_MANAGER` | Force `npm`, `pnpm` or `bun`.          |
| `node_install_flags`   | `--ignore-scripts` | `NODE_INSTALL_FLAGS`   | Flags for the locked install.          |
| `npm_ci_flags`         | unset (deprecated) | `NPM_CI_FLAGS`         | npm-only install flags; wins when set. |

There's no `e2e`: running an action for real would mutate refs, so actions are covered by unit tests.

## Source

??? abstract "archetypes/node/tasks.toml"

    ```toml
    --8<-- "archetypes/node/tasks.toml"
    ```

??? abstract "archetypes/node/scripts/pm.sh"

    ```sh
    --8<-- "archetypes/node/scripts/pm.sh"
    ```
