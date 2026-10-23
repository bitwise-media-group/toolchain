# terraform

The terraform archetype is for Terraform and OpenTofu modules: `cloud-accounts` environments and `safe-settings`. It
runs init, plan and apply, validates and lints, and generates module docs.

```toml
# mise.toml
[task_config]
includes = [".mise/common/tasks.toml", ".mise/archetypes/terraform/tasks.toml"]
```

```makefile
# Makefile (often in environments/<name>/)
include .mise/archetypes/terraform/include.mk
```

## Every task runs in the invoking directory

Terraform tasks run in `{{cwd}}`. The invoking Makefile usually lives below the repo root, in `environments/<name>/`,
and `plan` and `apply` must target that module. `cloud-accounts` keeps its own root fan-out (recursing into each
environment), and only the leaf environments adopt the archetype.

The prose passes still run from the repo root, so a repo-wide Markdown sweep rides along with each module's `fmt` and
`lint`.

## Tasks

| Task    | What it does                                                                            |
| ------- | --------------------------------------------------------------------------------------- |
| `init`  | `terraform init`, through `tf-run.sh`.                                                  |
| `plan`  | `terraform plan -out=plan.tfplan`, through `tf-run.sh`.                                 |
| `apply` | `plan`, then `terraform apply plan.tfplan`, through `tf-run.sh`.                        |
| `fmt`   | `terraform fmt -recursive`, then prose format.                                          |
| `lint`  | backend-less init, `terraform validate .`, tflint, containers, shell, workflows, prose. |
| `docs`  | `terraform-docs .`.                                                                     |
| `ci`    | `lint`, `docs`.                                                                         |
| `pr`    | `fmt`, `lint`, `docs`.                                                                  |

`lint` initialises the module with `-backend=false -input=false` first: `validate` needs an initialised module, but no
remote state.

!!! note "No license tasks"

    terraform is the one archetype without the license passes, because addlicense would stamp headers into `.tf` files.
    Its `pr` ends with `docs` rather than `commit`.

## OpenTofu

Set the `terraform_binary` knob and pin OpenTofu in the repo's root `[tools]`. The shared pins only cover terraform:

```toml
[tools]
"aqua:opentofu/opentofu" = "…"

[vars]
terraform_binary = "tofu"
```

Every task then drives `tofu` instead of `terraform`.

## Secrets with dotty

`archetypes/terraform/scripts/tf-run.sh` wraps every state-touching invocation (`init`, `plan`, `apply` and lint's
backend-less init):

```sh
if command -v dotty && [ -f .env.dotty ]; then
  exec dotty env run -- "$@"
fi
exec "$@"
```

- When the module directory has a `.env.dotty` **and** `dotty` is on `PATH`, secrets and environment are injected
  through `dotty env run`.
- Otherwise the command runs untouched. `dotty env run` fails hard when there's nothing to inject, so it's only used
  when there's a `.env.dotty`.

dotty is never mise-installed. It's a local-development convenience CI never needs, so the wrapper checks for it itself.
A module with a stale `.env.dotty` on a machine without dotty degrades to an uninjected run instead of blocking.

## Knobs

| Knob               | Default     | Meaning                                             |
| ------------------ | ----------- | --------------------------------------------------- |
| `terraform_binary` | `terraform` | The binary every task drives (`tofu` for OpenTofu). |

## Source

??? abstract "archetypes/terraform/tasks.toml"

    ```toml
    --8<-- "archetypes/terraform/tasks.toml"
    ```
