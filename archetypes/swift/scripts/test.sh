#!/bin/sh
# Copyright 2026 BitWise Media Group Ltd
# SPDX-License-Identifier: MIT
#
# swift test with code coverage, writing a JUnit report and an LCOV export
# under coverage/ (where the reusable CI workflow uploads from). Swift Testing
# results land in coverage/junit-swift-testing.xml beside the XCTest ones in
# coverage/junit.xml. The LCOV comes from llvm-cov — shipped in the pinned
# toolchain — over the test bundle SwiftPM built, minus dependency checkouts
# and the tests themselves. A package without a Tests/ directory is skipped
# with a message.
#
# SWIFT_TEST_FLAGS: extra `swift test` flags for one run, word-split on
# purpose (`make test SWIFT_TEST_FLAGS="--sanitize=thread --filter Parser"`).
set -eu

if [ ! -d Tests ]; then
  echo "swift-test: no Tests/ directory; skipping"
  exit 0
fi

mkdir -p coverage
# shellcheck disable=SC2086 # SWIFT_TEST_FLAGS is a flag list
swift test --enable-code-coverage --xunit-output coverage/junit.xml ${SWIFT_TEST_FLAGS:-}

bin="$(swift build --show-bin-path)"
profdata="$bin/codecov/default.profdata"
xctest=""
for bundle in "$bin"/*PackageTests.xctest; do
  if [ -d "$bundle" ]; then
    # macOS: a bundle with the executable inside.
    name="$(basename "$bundle" .xctest)"
    xctest="$bundle/Contents/MacOS/$name"
  elif [ -f "$bundle" ]; then
    # Linux: the executable itself.
    xctest="$bundle"
  fi
done

if [ -z "$xctest" ] || [ ! -f "$profdata" ]; then
  echo "swift-test: no test bundle or coverage profile produced; skipping the LCOV export"
  exit 0
fi

llvm-cov export -format=lcov -instr-profile="$profdata" \
  -ignore-filename-regex='\.build/|/Tests/' "$xctest" >coverage/lcov.info
echo "swift-test: coverage written to coverage/lcov.info"
