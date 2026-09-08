#!/bin/sh
# Copyright 2026 BitWise Media Group Ltd
# SPDX-License-Identifier: MIT
#
# pytest from the project's own environment, with a JUnit report and — when
# pytest-cov is a dev dependency — a Cobertura coverage report, both under
# coverage/ (where the reusable CI workflow uploads from). A project without
# pytest in its environment (a docs-only site) is skipped with a message;
# so is a suite that collects no tests (pytest exit code 5).
set -eu

has_module() { uv run --no-sync python -c "import $1" >/dev/null 2>&1; }

if ! has_module pytest; then
  echo "py-test: pytest is not in the project environment (add it to the dev dependencies); skipping"
  exit 0
fi

mkdir -p coverage
export COVERAGE_FILE=coverage/.coverage
set -- --junitxml=coverage/junit.xml
if has_module pytest_cov; then
  set -- "$@" --cov --cov-report=term --cov-report=xml:coverage/coverage.xml
fi

status=0
uv run --no-sync pytest "$@" || status=$?
if [ "$status" -eq 5 ]; then
  echo "py-test: no tests collected; skipping"
  exit 0
fi
exit "$status"
