#!/bin/sh
# Copyright 2026 BitWise Media Group Ltd
# SPDX-License-Identifier: MIT
#
# Run shellcheck over every *.sh under the repo's scripts/ and hack/
# directories (recursively; a comment must not start with the word
# "shellcheck" — that's directive syntax). Neither directory present →
# silent no-op. Starting the
# sweep at the repo-root directories keeps the library's own copies inside
# .mise/ out of consumer runs.
set -eu

set --
for d in scripts hack; do
  if [ -d "$d" ]; then set -- "$@" "$d"; fi
done
[ "$#" -gt 0 ] || exit 0

echo "lint-shell: shellcheck $*"
find "$@" -type f -name '*.sh' -exec shellcheck {} +
