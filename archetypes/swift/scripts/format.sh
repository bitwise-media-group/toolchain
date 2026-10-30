#!/bin/sh
# Copyright 2026 BitWise Media Group Ltd
# SPDX-License-Identifier: MIT
#
# swift format (shipped in the Swift toolchain the repo pins) over the repo's
# Swift sources. The file list comes from git — tracked plus untracked-but-not-
# ignored files — so dependency checkouts under .build/, the .mise submodule
# and anything ignored are never touched; .build/ and .swiftpm/ are excluded
# explicitly too, for a repo that forgot to ignore them. The repo's
# .swift-format configuration is picked up automatically. A repo with no Swift
# sources is skipped with a message.
#
#   format.sh fmt    swift format format --in-place
#   format.sh check  swift format lint --strict (warnings fail the gate)
set -eu

mode="${1-}"

case "$mode" in
  fmt) set -- format --in-place --parallel ;;
  check) set -- lint --strict --parallel ;;
  *)
    echo "usage: format.sh fmt|check" >&2
    exit 2
    ;;
esac

swift_files() {
  git ls-files -z --cached --others --exclude-standard -- '*.swift' \
    ':(exclude).build' ':(exclude).swiftpm'
}

if [ -z "$(swift_files | tr -d '\0' | head -c 1)" ]; then
  echo "swift format: no Swift sources; skipping"
  exit 0
fi

swift_files | xargs -0 swift format "$@"
