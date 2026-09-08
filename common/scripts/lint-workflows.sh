#!/bin/sh
# Copyright 2026 BitWise Media Group Ltd
# SPDX-License-Identifier: MIT
#
# Lint the repo's GitHub Actions workflows: actionlint for syntax/expression/
# shell errors, then zizmor for security findings (script injection, unpinned
# actions, excessive permissions, ...). No .github/workflows → silent no-op,
# so every archetype's `lint` carries this unconditionally. Repos silence
# accepted zizmor findings with a zizmor.yml (auto-loaded from the repo root
# or .github/); zizmor's online-only audits are skipped, with a notice, unless
# GH_TOKEN is exported.
#
# ZIZMOR_MIN_SEVERITY: lowest finding severity that fails the gate (the
# library's zizmor_min_severity var).
set -eu

: "${ZIZMOR_MIN_SEVERITY:=low}"

[ -d .github/workflows ] || exit 0

echo "lint-workflows: actionlint"
actionlint
echo "lint-workflows: zizmor --min-severity $ZIZMOR_MIN_SEVERITY .github/workflows"
zizmor --min-severity "$ZIZMOR_MIN_SEVERITY" .github/workflows
