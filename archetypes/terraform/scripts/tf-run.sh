#!/bin/sh
# Copyright 2026 BitWise Media Group Ltd
# SPDX-License-Identifier: MIT
#
# Wrapper for the terraform archetype's state-touching tasks: inject secrets
# via fnox when the working directory (the module being targeted) carries a
# fnox.toml, and run the command untouched otherwise. Plain, non-secret
# variables need no wrapper — they live in the module's mise.toml [env], which
# mise has already loaded into the task's environment. fnox is never
# mise-installed (dotty installs it on developer machines; CI never needs it —
# see config.toml): if it isn't on PATH, this falls through to running the
# command without injection rather than failing, so a module with secrets
# degrades to best-effort instead of blocking.
set -eu

if command -v fnox >/dev/null && [ -f fnox.toml ]; then
  exec fnox exec -- "$@"
fi
exec "$@"
