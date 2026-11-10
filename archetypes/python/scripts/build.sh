#!/bin/sh
# Copyright 2026 BitWise Media Group Ltd
# SPDX-License-Identifier: MIT
#
# Build whatever the project declares: `uv build` (sdist + wheel into dist/)
# when pyproject.toml has a [build-system] table, and `zensical build` (the
# docs site into site/) when a zensical.toml is present — either, both, or,
# with a message, neither.
set -eu

built=0

if [ -f pyproject.toml ] && grep -q '^\[build-system\]' pyproject.toml; then
  echo "py-build: uv build"
  uv build
  built=1
fi

if [ -f zensical.toml ]; then
  echo "py-build: zensical build"
  uv run --no-sync zensical build
  built=1
fi

[ "$built" -eq 1 ] || echo "py-build: nothing to build (no [build-system] in pyproject.toml, no zensical.toml)"
