#!/bin/sh
# Copyright 2026 BitWise Media Group Ltd
# SPDX-License-Identifier: MIT
#
# Unit tests with the race detector and a coverage profile. -covermode=atomic
# is the race-safe counter mode -race requires. gotestsum runs the suite and
# writes a JUnit report in one pass (propagating the exit code a bare
# `go test | …` pipe would swallow). Codecov ingests the native Go profile
# directly; coverage/ is where the reusable CI workflow uploads from.
#
# That full run happens on the host's GOOS only: a cross-compiled test binary
# cannot execute, so every other entry in the goos knob gets a compile-only
# pass — `go test -c` for every package, binaries discarded — which still
# fails on a platform-specific test file that no longer builds.
#
# The knob arrives as TOOLCHAIN_GOOS (space-separated); GOOS in the environment
# overrides it per invocation (`make test GOOS=windows`, or a list). Empty =
# the host's GOOS only. GOOS is unset after resolving so a list value never
# reaches a go invocation: each pass sets it explicitly per entry.
set -eu

host_goos="$(GOOS='' go env GOHOSTOS)"
goos_list="${GOOS:-${TOOLCHAIN_GOOS:-}}"; goos_list="${goos_list:-$host_goos}"
unset GOOS

for os in $goos_list; do
  if [ "$os" = "$host_goos" ]; then
    echo "==> test (GOOS=$os)"
    mkdir -p coverage
    GOOS="$os" gotestsum --junitfile coverage/junit.xml -- \
      -race -covermode=atomic -coverprofile=coverage/coverage.out ./...
  else
    echo "==> test (GOOS=$os, compile only)"
    out="$(mktemp -d "${TMPDIR:-/tmp}/go-test-$os.XXXXXX")"
    GOOS="$os" go test -c -o "$out/" ./... || { rm -rf "$out"; exit 1; }
    rm -rf "$out"
  fi
done
