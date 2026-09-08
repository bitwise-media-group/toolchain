#!/bin/sh
# Copyright 2026 BitWise Media Group Ltd
# SPDX-License-Identifier: MIT
#
# hadolint every root Dockerfile / Dockerfile.*, then grype the external base
# images named in FROM lines — pulled straight from their registries
# (registry: scheme, no docker daemon, no build). FROM targets naming an
# earlier build stage (AS alias) or scratch are skipped silently (normal
# multi-stage structure); simple ARG defaults are resolved first
# (ARG RUNTIME=static; FROM runtime-${RUNTIME} → the runtime-static alias),
# and refs still containing an unresolved variable are reported and skipped
# rather than guessed at. --platform linux/amd64: fleet images deploy to
# linux, and one platform keeps mac/CI results identical. --only-fixed: base
# images always carry will-not-fix distro CVEs; only a finding with an
# available fix (a newer base) is actionable enough to gate on.
set -eu

: "${GRYPE_FAIL_ON:=high}"

set --
for df in Dockerfile Dockerfile.*; do
  if [ -f "$df" ]; then set -- "$@" "$df"; fi
done
[ "$#" -gt 0 ] || exit 0

for df in "$@"; do
  echo "lint-docker: hadolint $df"
  hadolint "$df"
done

# Print the external base images of one Dockerfile (skips go to stderr).
# Aliases are recorded before variable resolution so `FROM ${BASE} AS build`
# still registers `build` even when ${BASE} has no default.
base_images() {
  awk -v df="$1" '
    toupper($1) == "ARG" {
      eq = index($2, "=")
      if (eq > 0) {
        val = substr($2, eq + 1); gsub(/^"|"$/, "", val)
        arg[substr($2, 1, eq - 1)] = val
      }
      next
    }
    toupper($1) == "FROM" {
      i = 2
      while (i <= NF && substr($i, 1, 2) == "--") i++   # --platform=... flags
      ref = $i
      if (toupper($(i + 1)) == "AS") alias[$(i + 2)] = 1
      while (match(ref, /\$\{[A-Za-z_][A-Za-z0-9_]*\}/)) {
        v = substr(ref, RSTART + 2, RLENGTH - 3)
        if (!(v in arg)) {
          printf "lint-docker: %s: skipping FROM %s (no default for ARG %s)\n", df, $i, v > "/dev/stderr"
          next
        }
        ref = substr(ref, 1, RSTART - 1) arg[v] substr(ref, RSTART + RLENGTH)
      }
      while (match(ref, /\$[A-Za-z_][A-Za-z0-9_]*/)) {
        v = substr(ref, RSTART + 1, RLENGTH - 1)
        if (!(v in arg)) {
          printf "lint-docker: %s: skipping FROM %s (no default for ARG %s)\n", df, $i, v > "/dev/stderr"
          next
        }
        ref = substr(ref, 1, RSTART - 1) arg[v] substr(ref, RSTART + RLENGTH)
      }
      if (tolower(ref) == "scratch") next
      if (ref in alias) next
      print ref
    }
  ' "$1"
}

# A grype failure propagates: set -eu is inherited by the while subshell, so
# the pipeline — and the script — exit non-zero.
for df in "$@"; do base_images "$df"; done | sort -u | while IFS= read -r img; do
  echo "lint-docker: grype registry:$img"
  grype --platform linux/amd64 --only-fixed --fail-on "$GRYPE_FAIL_ON" "registry:$img"
done
