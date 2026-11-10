#!/bin/sh
# Copyright 2026 BitWise Media Group Ltd
# SPDX-License-Identifier: MIT
#
# Build (`docs.sh build`) or live-preview (`docs.sh serve`) the Zensical docs
# site in the current directory. `uv sync` provisions Python + zensical from
# pyproject.toml/uv.lock, then zensical runs from that environment; the built
# site/ is git-ignored. Every archetype's build (terraform's docs) runs
# docs-build, so a directory with no zensical.toml — a repo without a site —
# is not an error: it skips with a message.
set -eu

mode=${1:?usage: docs.sh build|serve}

if [ ! -f zensical.toml ]; then
  echo "docs: no zensical.toml in $(pwd); no documentation site to $mode"
  exit 0
fi

uv sync
exec uv run --no-sync zensical "$mode"
