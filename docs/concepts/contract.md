# The CI contract

Every repo in the fleet runs the same CI: the reusable workflow in
[`bitwise-media-group/github-workflows`](https://github.com/bitwise-media-group/github-workflows). It doesn't know which
language a repo uses. It only knows a small set of task names.

## What CI runs

The reusable CI workflow runs a matrix of:

- **`make lint`**: every check-mode pass;
- **`make build`**: the binary, bundle, package or site;
- **`make test`**: unit tests with coverage into `coverage/`, which Codecov then uploads;
- **`make e2e`**: opt-in, for repos that define an end-to-end suite.

Each one is a separate parallel job. Before building the matrix, the workflow discovers which of these tasks the repo
actually defines:

```sh
mise tasks ls --name-only
```

It then **skips the rest**. A common-only Markdown repo has no `build` or `test` task, so CI runs `lint` alone. A Go CLI
defines all three, so CI runs all three.

Releases go through the reusable release workflow, which drives release-please, GoReleaser (when a `.goreleaser.yaml`
exists) and Zensical (when a `zensical.toml` exists) directly, not through make.

## No no-op stubs

Because CI discovers tasks, the library never defines a task that does nothing just to satisfy CI:

- An archetype defines only real work.
- A common-only repo has no `build` or `test` at all.
- A repo that grows a test suite or an e2e suite defines that task in its root `mise.toml [tasks]`, and CI picks it up
  on the next run.

The one tolerated exception is the **node** archetype. Its optional package.json scripts run only when the repo defines
them, so a library with no `test:coverage` script still gets a `test` task that passes trivially. The script set in
`package.json` is the repo's declaration of what applies.

The python archetype is similar in spirit: a project without ruff or pytest in its dev dependencies (a docs-only site)
skips those passes with a message rather than failing.

## The local gates

Every archetype also provides three tasks for local use:

| Task  | Purpose                                                                                      |
| ----- | -------------------------------------------------------------------------------------------- |
| `fmt` | Every auto-fix: the language formatter, prose formatting, license headers.                   |
| `ci`  | Exactly the gates CI runs, in sequence, so you can reproduce a CI failure locally.           |
| `pr`  | The full local gate: `fmt`, then everything `ci` runs, then `commit` (`./commit.sh` if any). |

`ci` and `pr` differ per archetype. `pr` for the go archetype also runs `tidy` first. See the
[task reference](../reference/tasks.md) for each archetype's exact sequence.

## Why make, if everything is mise?

The Makefile exists for two reasons: the CI contract (`make lint`) and muscle memory. All the logic lives in mise tasks,
and the make layer is a pure forwarder. That keeps the door open for the pipelines to invoke `mise run` directly without
changing anything in this library.
