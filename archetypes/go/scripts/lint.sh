#!/bin/sh
# Copyright 2026 BitWise Media Group Ltd
# SPDX-License-Identifier: MIT
#
# Check-mode static analysis, once per GOOS in the goos knob: golangci-lint
# and govulncheck both type-check the build for the GOOS they run under, so a
# platform-specific file is only analysed when that platform is in the list.
# Every configured platform runs before the script exits, so one gate reports
# every platform's findings; the exit code is the first failure.
#
# The knob arrives as TOOLCHAIN_GOOS (space-separated); GOOS in the environment
# overrides it per invocation (`make lint GOOS=windows`, or a list). Empty =
# the host's GOOS only. GOOS is unset after resolving so a list value never
# reaches a go invocation: each pass sets it explicitly per entry.
set -eu

host_goos="$(GOOS='' go env GOHOSTOS)"
goos_list="${GOOS:-${TOOLCHAIN_GOOS:-}}"; goos_list="${goos_list:-$host_goos}"
unset GOOS

status=0
for os in $goos_list; do
  echo "==> lint (GOOS=$os)"
  GOOS="$os" golangci-lint run || status=$?
  GOOS="$os" govulncheck ./... || status=$?
done
exit "$status"
