#!/bin/sh
# Copyright 2026 BitWise Media Group Ltd
# SPDX-License-Identifier: MIT
#
# addlicense over the current directory with the house default ignores
# (generated/vendored trees, incl. the .mise/ submodule, and the agent-prepared
# commit.sh handoff every repo may transiently carry) plus one -ignore per
# non-empty line of the repo's .licenseignore. Patterns never contain
# whitespace and must reach addlicense unexpanded (set -f stops the shell
# globbing them). A repo with no .licenseignore simply gets the defaults.
#
#   license.sh          inject headers
#   license.sh --check  check mode (non-zero on a missing header)
#
# LICENSE_HOLDER: the copyright holder (the library's license_holder var).
set -euf

: "${LICENSE_HOLDER:=BitWise Media Group Ltd}"
mode="${1-}"

set -- -ignore 'node_modules/**' -ignore '.mise/**' -ignore '.claude/**' \
  -ignore '.venv/**' -ignore 'coverage/**' -ignore 'commit.sh'
if [ -f .licenseignore ]; then
  while IFS= read -r pattern || [ -n "$pattern" ]; do
    [ -n "$pattern" ] || continue
    set -- "$@" -ignore "$pattern"
  done <.licenseignore
fi
if [ "$mode" = "--check" ]; then set -- "$@" -check; fi

addlicense -l mit -c "$LICENSE_HOLDER" -s=only "$@" .
