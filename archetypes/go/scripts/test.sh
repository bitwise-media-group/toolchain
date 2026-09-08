#!/bin/sh
# Copyright 2026 BitWise Media Group Ltd
# SPDX-License-Identifier: MIT
#
# Unit tests with the race detector and a coverage profile. -covermode=atomic
# is the race-safe counter mode -race requires. gotestsum runs the suite and
# writes a JUnit report in one pass (propagating the exit code a bare
# `go test | …` pipe would swallow). Codecov ingests the native Go profile
# directly; coverage/ is where the reusable CI workflow uploads from.
set -eu

mkdir -p coverage
gotestsum --junitfile coverage/junit.xml -- \
  -race -covermode=atomic -coverprofile=coverage/coverage.out ./...
