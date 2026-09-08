#!/bin/sh
# Copyright 2026 BitWise Media Group Ltd
# SPDX-License-Identifier: MIT
#
# ruff over the project, from the project's own environment (`uv run`, no
# global ruff): the repo pins its ruff in its dev dependencies. A project
# without ruff in its environment (a docs-only site) is skipped with a
# message, so fmt/lint still pass there.
#
#   ruff.sh fmt    ruff format, then ruff check --fix
#   ruff.sh check  ruff check, then ruff format --check
set -eu

mode="${1-}"

if ! uv run --no-sync python -m ruff --version >/dev/null 2>&1; then
  echo "ruff: not in the project environment (add it to the dev dependencies); skipping"
  exit 0
fi

case "$mode" in
  fmt)
    uv run --no-sync ruff format
    uv run --no-sync ruff check --fix
    ;;
  check)
    uv run --no-sync ruff check
    uv run --no-sync ruff format --check
    ;;
  *)
    echo "usage: ruff.sh fmt|check" >&2
    exit 2
    ;;
esac
