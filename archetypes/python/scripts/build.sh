#!/bin/sh
# Copyright 2026 BitWise Media Group Ltd
# SPDX-License-Identifier: MIT
#
# Build the package — `uv build` (sdist + wheel into dist/) — when
# pyproject.toml has a [build-system] table, and skip with a message when it
# has none (a docs-only site). The docs site itself is common's docs-build,
# which the build rollup runs next.
set -eu

if [ -f pyproject.toml ] && grep -q '^\[build-system\]' pyproject.toml; then
  echo "py-build: uv build"
  exec uv build
fi

echo "py-build: no [build-system] in pyproject.toml; no package to build"
