#!/bin/sh
# Copyright 2026 BitWise Media Group Ltd
# SPDX-License-Identifier: MIT
#
# Wrapper for the terraform archetype's state-touching tasks: inject secrets
# via fnox when the working directory (the module being targeted) carries a
# fnox.toml, and run the command untouched otherwise. Plain, non-secret
# variables need no wrapper — they live in the module's mise.toml [env], which
# mise has already loaded into the task's environment. fnox is a shared lazy
# pin (see config.toml), so it's always on the task's PATH and installs on
# first use. A secret it can't resolve (a CI job without vault access, say)
# only warns by default and the command still runs; FNOX_IF_MISSING or the
# module's own if_missing setting makes that strict or silent.
set -eu

if [ -f fnox.toml ]; then
  exec fnox exec -- "$@"
fi
exec "$@"
