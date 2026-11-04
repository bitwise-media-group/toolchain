#!/bin/sh
# Copyright 2026 BitWise Media Group Ltd
# SPDX-License-Identifier: MIT
#
# Prose format/check via the pinned prettier + markdownlint-cli2 over every
# *.md under the current directory (the repo root — the tasks run from
# config_root). The house defaults are the library's own .prettierrc.yaml /
# .prettierignore / .markdownlint-cli2.yaml, read from .mise/ unless the repo
# carries its own copy of a file, which then overrides that file wholesale.
# Patterns in the house ignore files are deliberately unanchored — prettier
# and markdownlint resolve them against the invoking repo, not against .mise/.
# Both tools run on the pinned bun, not Node.js: their aube shims
# `exec node …`, so the script's sibling bin/ (whose `node` execs bun) goes
# first on PATH, resolved from the script's own path rather than the cwd.
#
#   prose.sh fmt    prettier --write, then markdownlint-cli2 --fix
#   prose.sh check  markdownlint-cli2, then prettier --check
set -eu

bindir=$(CDPATH='' cd -- "$(dirname -- "$0")/../bin" && pwd)
PATH="$bindir:$PATH"
export PATH

mode="${1-}"

pcfg=".prettierrc.yaml";        [ -f "$pcfg" ] || pcfg=".mise/.prettierrc.yaml"
pign=".prettierignore";         [ -f "$pign" ] || pign=".mise/.prettierignore"
mcfg=".markdownlint-cli2.yaml"; [ -f "$mcfg" ] || mcfg=".mise/.markdownlint-cli2.yaml"

case "$mode" in
  fmt)
    prettier --config "$pcfg" --ignore-path .gitignore --ignore-path "$pign" \
      --no-error-on-unmatched-pattern --write "**/*.md"
    markdownlint-cli2 --config "$mcfg" --fix
    ;;
  check)
    markdownlint-cli2 --config "$mcfg"
    prettier --config "$pcfg" --ignore-path .gitignore --ignore-path "$pign" \
      --no-error-on-unmatched-pattern --check "**/*.md"
    ;;
  *)
    echo "usage: prose.sh fmt|check" >&2
    exit 2
    ;;
esac
