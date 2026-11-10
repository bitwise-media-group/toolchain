#!/bin/sh
# Copyright 2026 BitWise Media Group Ltd
# SPDX-License-Identifier: MIT
#
# Build the documentation site when the repo carries one (zensical.toml at
# the root), through the docs-build task by name rather than common's script:
# a repo whose pages embed generated content overrides docs-build to generate
# it first (flux-containers renders its chart reference pages), and that
# override is what must run. No site is not an error — the archetype's build
# also covers repos without one — so it skips with a message.
set -eu

if [ ! -f zensical.toml ]; then
  echo "site-build: no zensical.toml; no documentation site to build"
  exit 0
fi

exec mise run docs-build
