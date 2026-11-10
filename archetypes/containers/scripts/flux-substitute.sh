#!/bin/sh
# Copyright 2026 BitWise Media Group Ltd
# SPDX-License-Identifier: MIT
#
# Substitute variables into rendered Kubernetes YAML the way Flux's
# kustomize-controller does for a Kustomization's postBuild.substitute /
# substituteFrom — faithfully enough that a render which passes here passes
# on a cluster. A helper for a repo's own Flux validation harness:
#
#   flux-substitute.sh <in> <out>    substitute from the environment
#   flux-substitute.sh --self-test   prove the null guard still trips
#
# Export the variables first (set -a; . tests/cluster.env; set +a). Three
# behaviours of the controller are reproduced:
#
#   1. Strict mode: a bare ${VAR} whose VAR is unset fails, the way the
#      controller fails a Kustomization whose ConfigMaps never publish VAR.
#      ${VAR:=default} and ${VAR:-default} always satisfy it.
#   2. The round trip: parse, re-serialize (redundant quotes drop),
#      substitute TEXTUALLY, re-parse — so an empty value in a quoted scalar
#      ("${VAR}") becomes null on a cluster, and here.
#   3. The null guard: no path that held a ${VAR}-bearing string may hold
#      null afterwards. On a cluster that failure surfaces only at apply time;
#      the fixes are to gate the key absent, quote through a ResourceSet
#      (<< "${VAR:=}" | quote >>), or move the value into a resourcesTemplate.
#
# The controller substitutes only the braced form, so a bare $VAR (dex
# config, Go templates) passes through untouched here too. Needs yq v4.
set -eu

usage() {
  echo "usage: flux-substitute.sh <in> <out> | --self-test" >&2
  exit 2
}

# check_strict fails on a bare ${VAR} whose VAR is unset.
check_strict() { # check_strict <file>
  # shellcheck disable=SC2016 # the dollar-brace is the grep pattern, not an expansion
  vars=$(grep -oE '\$\{[A-Z][A-Z0-9_]*\}' "$1" | tr -d '${}' | sort -u || true)
  for var in $vars; do
    isset=""
    # var matches [A-Z][A-Z0-9_]*, so the eval only ever reads ${NAME+x}.
    eval "isset=\${$var+x}"
    if [ -z "$isset" ]; then
      echo "strict substitution: \${$var} in $1 but $var is not set in the environment" >&2
      exit 1
    fi
  done
}

# null_guard fails when a ${VAR}-bearing scalar in <pre> became null in <post>.
null_guard() { # null_guard <pre-file> <post-file>
  scratch=$(mktemp -d "${TMPDIR:-/tmp}/flux-substitute.XXXXXX")
  # shellcheck disable=SC2016 # yq expressions, not shell expansions
  yq ea '.. | select(tag == "!!str") | select(test("\$\{[A-Z]")) | ([document_index] + path | join("/"))' "$1" |
    grep -v '^---$' | sort -u >"$scratch/pre"
  yq ea '.. | select(tag == "!!null") | ([document_index] + path | join("/"))' "$2" |
    grep -v '^---$' | sort -u >"$scratch/nulls"
  hits=$(comm -12 "$scratch/pre" "$scratch/nulls" | grep -v '^$' || true)
  rm -rf "$scratch"
  if [ -n "$hits" ]; then
    {
      echo "null substitution in $2: these \${VAR}-bearing scalars became null (document/path):"
      printf '%s\n' "$hits" | sed 's/^/  /'
      echo "gate the key absent, quote it through a ResourceSet (<< \"\${VAR:=}\" | quote >>), or move it into a resourcesTemplate"
    } >&2
    exit 1
  fi
}

# substitute reproduces postBuild substitution of <in> into <out>.
substitute() { # substitute <in> <out>
  check_strict "$1"
  # shellcheck disable=SC2016 # yq expression
  yq ea '(.. | select(kind == "scalar")) style=""' "$1" >"$2.norm"
  # yq's envsubst would also eat a bare $VAR, which the controller leaves
  # alone: shield those behind a sentinel for the duration.
  # shellcheck disable=SC2016 # ${1} and $$ are yq syntax; single quotes are deliberate
  IN_FILE="$2.norm" yq -n 'load_str(strenv(IN_FILE)) | sub("\$([^{])"; "@BARE_DOLLAR@${1}") | envsubst | sub("@BARE_DOLLAR@"; "$$")' >"$2"
  null_guard "$2.norm" "$2"
  rm -f "$2.norm"
}

# self_test proves the guard trips on the case it exists for, so it cannot
# rot silently: an empty var in a quoted scalar must fail, a set one pass.
self_test() {
  dir=$(mktemp -d "${TMPDIR:-/tmp}/flux-substitute.XXXXXX")
  cat >"$dir/canary.yaml" <<'YAML'
canary:
  trip: "${FLUX_SUBSTITUTE_SELFTEST_EMPTY}"
  control: "${FLUX_SUBSTITUTE_SELFTEST_PRESENT}"
YAML
  FLUX_SUBSTITUTE_SELFTEST_EMPTY="" FLUX_SUBSTITUTE_SELFTEST_PRESENT=present
  export FLUX_SUBSTITUTE_SELFTEST_EMPTY FLUX_SUBSTITUTE_SELFTEST_PRESENT
  if (substitute "$dir/canary.yaml" "$dir/out.yaml") 2>/dev/null; then
    rm -rf "$dir"
    echo "flux-substitute self-test: the null guard did NOT trip on an empty var in a quoted scalar" >&2
    exit 1
  fi
  FLUX_SUBSTITUTE_SELFTEST_EMPTY=non-empty
  if ! (substitute "$dir/canary.yaml" "$dir/out.yaml"); then
    rm -rf "$dir"
    echo "flux-substitute self-test: substitution failed its positive control" >&2
    exit 1
  fi
  rm -rf "$dir"
  echo "flux-substitute: self-test passed"
}

command -v yq >/dev/null || {
  echo "flux-substitute: yq not found" >&2
  exit 1
}

case "${1:-}" in
  --self-test)
    [ $# -eq 1 ] || usage
    self_test
    ;;
  -*) usage ;;
  *)
    [ $# -eq 2 ] || usage
    substitute "$1" "$2"
    ;;
esac
