#!/bin/sh
# Copyright 2026 BitWise Media Group Ltd
# SPDX-License-Identifier: MIT
#
# Wrapper for the terraform archetype's state-touching tasks: inject
# secrets/env via dotty when the working directory (the module being targeted)
# carries a .env.dotty, and run the command untouched otherwise — dotty env
# run fails hard when it has nothing to inject. dotty is never mise-installed
# (a local-dev convenience CI never needs — see config.toml): if dotty isn't
# on PATH, this falls through to running the command without injection rather
# than failing, so a module with a stale/misconfigured .env.dotty degrades to
# best-effort instead of blocking.
set -eu

if command -v dotty && [ -f .env.dotty ]; then
  exec dotty env run -- "$@"
fi
exec "$@"
