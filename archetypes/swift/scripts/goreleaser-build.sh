#!/bin/sh
# Copyright 2026 BitWise Media Group Ltd
# SPDX-License-Identifier: MIT
#
# GoReleaser `tool` shim: lets a repo's .goreleaser.yaml drive `swift build`
# through the go builder, since GoReleaser OSS has no Swift builder.
# GoReleaser runs it as `<tool> build [go flags] -o <out> <main>` with GOOS and
# GOARCH set for the target; the shim maps that pair to a Swift target, builds
# the product in release mode, and copies the binary to <out>. Go-only flags
# (-ldflags, -trimpath, -tags, …) and <main> are ignored.
#
#   builds:
#     - builder: go
#       tool: .mise/archetypes/swift/scripts/goreleaser-build.sh
#       no_main_check: true   # there is no Go main package to find
#       env: [SWIFT_PRODUCT=mytool]
#       goos: [darwin]
#       goarch: [arm64, amd64]
#
# The product comes from SWIFT_PRODUCT (the build's env) or the swift_product
# knob (TOOLCHAIN_SWIFT_PRODUCT, set by the snapshot/release tasks).
#
#   darwin/arm64  --triple arm64-apple-macosx
#   darwin/amd64  --triple x86_64-apple-macosx
#   linux/amd64   --swift-sdk x86_64-swift-linux-musl    (Static Linux SDK)
#   linux/arm64   --swift-sdk aarch64-swift-linux-musl   (Static Linux SDK)
#
# The Linux targets build fully static binaries with the Static Linux SDK
# matching the pinned toolchain (`swift sdk install …`, see swift.org); they
# work from a macOS or a Linux host alike.
set -eu

out=""
while [ $# -gt 0 ]; do
  case "$1" in
    -o)
      out="${2-}"
      if [ $# -gt 1 ]; then shift; fi
      shift
      ;;
    -o=*)
      out="${1#-o=}"
      shift
      ;;
    *) shift ;;
  esac
done

if [ -z "$out" ]; then
  echo "goreleaser-build.sh: no -o <output> argument (run it as a GoReleaser build tool)" >&2
  exit 2
fi

product="${SWIFT_PRODUCT:-${TOOLCHAIN_SWIFT_PRODUCT:-}}"
if [ -z "$product" ]; then
  echo "goreleaser-build.sh: no product — set SWIFT_PRODUCT in the build's env or the swift_product knob" >&2
  exit 2
fi

target="${GOOS:-}/${GOARCH:-}"
case "$target" in
  darwin/arm64) set -- --triple arm64-apple-macosx ;;
  darwin/amd64) set -- --triple x86_64-apple-macosx ;;
  linux/amd64) set -- --swift-sdk x86_64-swift-linux-musl ;;
  linux/arm64) set -- --swift-sdk aarch64-swift-linux-musl ;;
  *)
    echo "goreleaser-build.sh: unsupported target $target (darwin|linux × arm64|amd64)" >&2
    exit 2
    ;;
esac

echo "==> swift build $product ($target)"
swift build -c release "$@" --product "$product"
bin="$(swift build -c release "$@" --show-bin-path)"

mkdir -p "$(dirname "$out")"
cp "$bin/$product" "$out"
