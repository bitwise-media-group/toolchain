#!/bin/sh
# Copyright 2026 BitWise Media Group Ltd
# SPDX-License-Identifier: MIT
#
# Fuzz one target: FUZZ=FuzzName (default: the package's only fuzz test —
# `go test -fuzz` refuses to run when the pattern matches more than one),
# FUZZTIME=20s, FUZZ_PKG=./pkg. `go test -fuzz` accepts a single package only,
# so FUZZ_PKG must name one.
set -eu

go test -run '^$' -fuzz "^${FUZZ:-.*}$" -fuzztime "${FUZZTIME:-20s}" "${FUZZ_PKG:-./...}"
