#!/bin/sh
# Copyright 2026 BitWise Media Group Ltd
# SPDX-License-Identifier: MIT
#
# Prose format/check over every *.md under the current directory (the repo
# root — the tasks run from config_root): `bun fmt` (bun's built-in,
# Prettier-compatible formatter) for layout, markdownlint-cli2 for the rules.
# The house defaults are the library's own .prettierrc.yaml / .prettierignore
# / .markdownlint-cli2.yaml, read from .mise/ unless the repo carries its own
# copy of a file, which then overrides that file wholesale. Patterns in the
# house ignore files are deliberately unanchored — bun fmt and markdownlint
# resolve them against the invoking repo, not against .mise/.
#
# bun fmt runs a package.json "fmt" script instead of formatting when one
# exists, so it always gets --no-script. markdownlint-cli2 is an npm package
# whose aube shim `exec`s node; it runs on the pinned bun instead because the
# script's sibling bin/ (whose `node` execs bun) goes first on PATH, resolved
# from the script's own path rather than the cwd.
#
#   prose.sh fmt    bun fmt, then markdownlint-cli2 --fix
#   prose.sh check  markdownlint-cli2, then bun fmt --check
set -eu

bindir=$(CDPATH='' cd -- "$(dirname -- "$0")/../bin" && pwd)
PATH="$bindir:$PATH"
export PATH

mode="${1-}"

pcfg=".prettierrc.yaml";        [ -f "$pcfg" ] || pcfg=".mise/.prettierrc.yaml"
pign=".prettierignore";         [ -f "$pign" ] || pign=".mise/.prettierignore"
mcfg=".markdownlint-cli2.yaml"; [ -f "$mcfg" ] || mcfg=".mise/.markdownlint-cli2.yaml"

fmt() {
  bun fmt --no-script --config "$pcfg" --ignore-path .gitignore --ignore-path "$pign" \
    --no-error-on-unmatched-pattern "$@" "**/*.md"
}

case "$mode" in
  fmt)
    fmt
    markdownlint-cli2 --config "$mcfg" --fix
    ;;
  check)
    markdownlint-cli2 --config "$mcfg"
    fmt --check
    ;;
  *)
    echo "usage: prose.sh fmt|check" >&2
    exit 2
    ;;
esac
