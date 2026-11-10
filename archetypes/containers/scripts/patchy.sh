#!/bin/sh
# Copyright 2026 BitWise Media Group Ltd
# SPDX-License-Identifier: MIT
#
# The containers archetype's front end to patchy: run one `patchy build` or
# `patchy mirror` command over the entries the caller selects.
#
#   patchy.sh build [flags...]           e.g. patchy.sh build --dry-run
#   patchy.sh mirror <verb> [flags...]   e.g. patchy.sh mirror validate --only lint
#
# Selection comes from the environment, so `make <task> ENTRY=x` and
# `ENTRY=x mise run <task>` agree: ENTRY names one or more entries
# (space-separated) and, unset, the command covers every entry (--all) —
# unless the flags already pick a lockstep group (--group). REGISTRY
# (space-separated) narrows publishing to the named registries; it reaches
# only the commands that take --registry (build, mirror sync). Anything after
# `--` on `mise run` arrives here after the task's own flags
# (`mise run mirror-validate -- -o markdown`).
#
# For patchy build, the variables a tag template conventionally reads are
# derived from git when unset, so one set of templates expands the same on a
# workstation and in CI — a CI job that exports its own wins:
#   GIT_COMMIT         the HEAD commit (templates take ${GIT_COMMIT:0:7})
#   SOURCE_DATE_EPOCH  its commit time, so buildx output is reproducible and
#                      ${PATCHY_TIMESTAMP} repeats when a commit is rebuilt
#   VERSION            the release-please manifest's root version, else the
#                      newest vX.Y.Z tag, else 0.0.0
set -eu

[ $# -ge 1 ] || {
  echo "usage: patchy.sh build|mirror <verb> [flags...]" >&2
  exit 2
}

# release_version prints the version edge builds base their tags on: the last
# release. The release-please manifest is read first because it is in the
# tree, so it also works in a shallow CI checkout that fetched no tags.
release_version() {
  v=""
  if [ -f .release-please-manifest.json ]; then
    v=$(tr -d ' \n\t' <.release-please-manifest.json | sed -n 's/.*"\."[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
  fi
  if [ -z "$v" ]; then
    v=$(git describe --tags --abbrev=0 --match 'v[0-9]*' 2>/dev/null || true)
    v=${v#v}
  fi
  echo "${v:-0.0.0}"
}

publishes=0
case "$1" in
  build)
    publishes=1
    if [ -z "${GIT_COMMIT:-}" ]; then
      GIT_COMMIT=$(git rev-parse HEAD 2>/dev/null || true)
    fi
    if [ -z "${SOURCE_DATE_EPOCH:-}" ]; then
      SOURCE_DATE_EPOCH=$(git log -1 --format=%ct 2>/dev/null || true)
    fi
    if [ -z "${VERSION:-}" ]; then
      VERSION=$(release_version)
    fi
    # An empty value (no git checkout) stays unset, so a template that needs
    # it fails with patchy's own "${GIT_COMMIT} is not set" message.
    [ -z "$GIT_COMMIT" ] || export GIT_COMMIT
    [ -z "$SOURCE_DATE_EPOCH" ] || export SOURCE_DATE_EPOCH
    export VERSION
    ;;
  mirror)
    [ "${2:-}" != sync ] || publishes=1
    ;;
  *)
    echo "patchy.sh: unknown command group '$1' (want build or mirror)" >&2
    exit 2
    ;;
esac

group=0
for arg in "$@"; do
  case "$arg" in
    --group | --group=*) group=1 ;;
  esac
done

if [ -n "${ENTRY:-}" ]; then
  # shellcheck disable=SC2086 # ENTRY is a space-separated list of names
  set -- "$@" $ENTRY
elif [ "$group" -eq 0 ]; then
  set -- "$@" --all
fi

if [ "$publishes" -eq 1 ]; then
  for registry in ${REGISTRY:-}; do
    set -- "$@" --registry "$registry"
  done
fi

exec patchy "$@"
