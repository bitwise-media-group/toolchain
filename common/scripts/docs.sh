#!/bin/sh
# Copyright 2026 BitWise Media Group Ltd
# SPDX-License-Identifier: MIT
#
# Build (`docs.sh build`) or live-preview (`docs.sh serve`) the Zensical docs
# site in the current directory. `uv sync` provisions Python + zensical from
# pyproject.toml/uv.lock, then zensical runs from that environment; the built
# site/ is git-ignored. Every repo carries these tasks, so a directory with no
# zensical.toml fails with a pointer instead of uv's missing-pyproject error.
set -eu

mode=${1:?usage: docs.sh build|serve}

if [ ! -f zensical.toml ]; then
  echo "docs: no zensical.toml in $(pwd) — run from the docs site's root (a site needs zensical.toml plus a pyproject.toml depending on zensical)" >&2
  exit 1
fi

uv sync
exec uv run --no-sync zensical "$mode"
