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

## Variables and secrets

Plain, non-secret variables — a service account to impersonate, a region — go in the module's own `mise.toml`:

```toml
[env]
GOOGLE_IMPERSONATE_SERVICE_ACCOUNT = "terraform-apply@o-foundation-1234.iam.gserviceaccount.com"
```

mise loads `[env]` from the invoking directory into every task, so they reach `terraform` with no wrapper (and into the
shell on `cd`, for running `terraform` by hand). mise expands `$VARS` and `{{ … }}` templates in these values.

Secrets go in the module's `fnox.toml`. `archetypes/terraform/scripts/tf-run.sh` wraps every state-touching invocation
(`init`, `plan`, `apply` and lint's backend-less init):

```sh
if [ -f fnox.toml ]; then
  exec fnox exec -- "$@"
fi
exec "$@"
```

- When the module directory has a `fnox.toml`, its secrets are injected through `fnox exec`.
- Otherwise the command runs untouched.

fnox is a shared lazy pin (see [Secrets with fnox](../concepts/tools.md#secrets-with-fnox)), so it's installed the first
time a module with a `fnox.toml` runs a task. CI runs the wrapper too, through lint's backend-less init. A secret the
runner can't resolve only warns by default, so lint still runs. A module that sets `if_missing = "error"` needs vault
access in CI, or `FNOX_IF_MISSING=warn` on the job.

`dotty env migrate` converts a legacy `.env.dotty` into both files: its plain lines into `mise.toml`, its
`{{ dotty://… }}` references into `fnox.toml`.

## Knobs

| Knob               | Default     | Meaning                                             |
| ------------------ | ----------- | --------------------------------------------------- |
| `terraform_binary` | `terraform` | The binary every task drives (`tofu` for OpenTofu). |

## Source

??? abstract "archetypes/terraform/tasks.toml"

    ```toml
    --8<-- "archetypes/terraform/tasks.toml"
    ```
