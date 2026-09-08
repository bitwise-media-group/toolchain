#!/bin/sh
# Copyright 2026 BitWise Media Group Ltd
# SPDX-License-Identifier: MIT
#
# Build the application binary with version metadata stamped in via -ldflags.
# GoReleaser injects the same vars at the same import path on tagged releases.
#
# Structural defaults arrive as TOOLCHAIN_* (the library's app / app_pkg /
# build_tags / version_pkg vars); the plain spellings (APP, APP_PKG,
# BUILD_TAGS, VERSION_PKG) and the per-invocation VERSION, COMMIT, DATE,
# LDFLAGS, MODULE are environment overrides — `make build VERSION=x` works
# because make exports command-line variables to recipe subshells.
set -eu

app="${APP:-${TOOLCHAIN_APP:-}}"; app="${app:-$(basename "$PWD")}"
app_pkg="${APP_PKG:-${TOOLCHAIN_APP_PKG:-.}}"
module="${MODULE:-$(go list -m 2>/dev/null || true)}"
version="${VERSION:-$(git describe --tags --always --dirty 2>/dev/null || echo dev)}"
commit="${COMMIT:-$(git rev-parse --short HEAD 2>/dev/null || echo none)}"
date="${DATE:-$(date -u +%Y-%m-%dT%H:%M:%SZ)}"
version_pkg="${VERSION_PKG:-${TOOLCHAIN_VERSION_PKG:-}}"; version_pkg="${version_pkg:-$module/internal/version}"
build_tags="${BUILD_TAGS:-${TOOLCHAIN_BUILD_TAGS:-}}"
ldflags="${LDFLAGS:--s -w \
  -X $version_pkg.Version=$version \
  -X $version_pkg.Commit=$commit \
  -X $version_pkg.BuildDate=$date}"

if [ -n "$build_tags" ]; then
  CGO_ENABLED=0 go build -trimpath -tags "$build_tags" -ldflags "$ldflags" -o "$app" "$app_pkg"
else
  CGO_ENABLED=0 go build -trimpath -ldflags "$ldflags" -o "$app" "$app_pkg"
fi
