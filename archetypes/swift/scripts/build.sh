#!/bin/sh
# Copyright 2026 BitWise Media Group Ltd
# SPDX-License-Identifier: MIT
#
# Release build of the package: every product, or the one the swift_product
# knob (arriving as TOOLCHAIN_SWIFT_PRODUCT) names. SWIFT_PRODUCT in the
# environment overrides the knob per invocation (`make build
# SWIFT_PRODUCT=mytool`). Prints where the binaries landed.
#
# No version stamping: Swift has no -X/-ldflags equivalent. A repo that wants
# its version in the binary generates a source file in a repo-local task that
# runs before `build`.
set -eu

product="${SWIFT_PRODUCT:-${TOOLCHAIN_SWIFT_PRODUCT:-}}"

if [ -n "$product" ]; then
  swift build -c release --product "$product"
else
  swift build -c release
fi

echo "swift-build: binaries in $(swift build -c release --show-bin-path)"
