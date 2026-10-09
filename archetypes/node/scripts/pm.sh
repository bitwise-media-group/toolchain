#!/bin/sh
# Copyright 2026 BitWise Media Group Ltd
# SPDX-License-Identifier: MIT
#
# Package-manager dispatcher for the node archetype: the tasks never spell out
# npm, pnpm or bun themselves, they call this script.
#
#   pm.sh install                    install exactly as locked, then touch the
#                                    node_modules/.toolchain-install sentinel
#   pm.sh run <script> [args...]     run a required package.json script
#   pm.sh run-if-present <script>... run each script the package.json defines,
#                                    silently skipping the rest
#
# The package manager is, in order: NODE_PACKAGE_MANAGER in the environment,
# else the node_package_manager var (TOOLCHAIN_NODE_PM); else the name in
# package.json "packageManager"; else the lockfile present in the repo
# (conflicting lockfiles fail); else npm.
#
# Install flags are, in order: NODE_INSTALL_FLAGS in the environment
# (unset-only, so NODE_INSTALL_FLAGS= forces none); for npm only, NPM_CI_FLAGS
# in the environment (unset-only) or the deprecated npm_ci_flags var if the
# repo sets it; else the node_install_flags var (TOOLCHAIN_NODE_INSTALL_FLAGS),
# plus --no-fund for npm.
set -eu

die() {
  echo "pm.sh: $*" >&2
  exit 1
}

check_pm() {
  case "$1" in
    npm | pnpm | bun) ;;
    *) die "unsupported package manager '$1' from $2 (expected npm, pnpm or bun)" ;;
  esac
}

# node is always on PATH (the repo's node pin, or the shared one), so it reads
# package.json rather than a JSON-parsing dependency. Prints the field's
# package-manager name (the part before '@'), or nothing.
package_manager_field() {
  [ -f package.json ] || return 0
  node -e '
    const pm = JSON.parse(require("fs").readFileSync("package.json", "utf8")).packageManager;
    if (typeof pm === "string") console.log(pm.split("@")[0]);
  '
}

detect_lockfiles() {
  families=""
  found=""
  for f in package-lock.json npm-shrinkwrap.json pnpm-lock.yaml bun.lock bun.lockb; do
    [ -f "$f" ] || continue
    case "$f" in
      package-lock.json | npm-shrinkwrap.json) family=npm ;;
      pnpm-lock.yaml) family=pnpm ;;
      *) family=bun ;;
    esac
    found="${found:+$found, }$f"
    case " $families " in
      *" $family "*) ;;
      *) families="${families:+$families }$family" ;;
    esac
  done
  case "$families" in
    *" "*) die "conflicting lockfiles ($found); set node_package_manager in the root mise.toml [vars] (or \"packageManager\" in package.json) to pick one" ;;
  esac
  echo "$families"
}

resolve_pm() {
  if [ -n "${NODE_PACKAGE_MANAGER-}" ]; then
    check_pm "$NODE_PACKAGE_MANAGER" NODE_PACKAGE_MANAGER
    pm=$NODE_PACKAGE_MANAGER
    return
  fi
  if [ -n "${TOOLCHAIN_NODE_PM-}" ]; then
    check_pm "$TOOLCHAIN_NODE_PM" "the node_package_manager var"
    pm=$TOOLCHAIN_NODE_PM
    return
  fi
  pm=$(package_manager_field)
  if [ -n "$pm" ]; then
    check_pm "$pm" 'package.json "packageManager"'
    return
  fi
  pm=$(detect_lockfiles)
  [ -n "$pm" ] || pm=npm
}

install_flags() {
  if [ "${NODE_INSTALL_FLAGS+set}" = set ]; then
    echo "$NODE_INSTALL_FLAGS"
  elif [ "$pm" = npm ] && [ "${NPM_CI_FLAGS+set}" = set ]; then
    echo "$NPM_CI_FLAGS"
  elif [ "$pm" = npm ] && [ -n "${TOOLCHAIN_NPM_CI_FLAGS_SET-}" ]; then
    echo "${TOOLCHAIN_NPM_CI_FLAGS-}"
  elif [ "$pm" = npm ]; then
    echo "${TOOLCHAIN_NODE_INSTALL_FLAGS-} --no-fund"
  else
    echo "${TOOLCHAIN_NODE_INSTALL_FLAGS-}"
  fi
}

# package.json scripts are an object of name → command; exit 0 when the named
# one exists, 1 when it does not, 2 when package.json cannot be read.
has_script() {
  node -e '
    let scripts;
    try {
      scripts = JSON.parse(require("fs").readFileSync("package.json", "utf8")).scripts;
    } catch (e) {
      console.error("pm.sh: cannot read package.json: " + e.message);
      process.exit(2);
    }
    process.exit(scripts && Object.hasOwn(scripts, process.argv[1]) ? 0 : 1);
  ' "$1"
}

run() {
  echo "$*" >&2
  "$@"
}

[ $# -ge 1 ] || die "usage: pm.sh install | run <script> [args...] | run-if-present <script>..."
cmd=$1
shift
resolve_pm

# Every pnpm command (run included) would otherwise download and switch to the
# version package.json "packageManager" names, bypassing the checksum-locked
# mise pin. pmOnFail=warn (pnpm 11+) keeps the pinned pnpm and reports the
# mismatch; manage-package-manager-versions is the pnpm 10 spelling.
if [ "$pm" = pnpm ]; then
  export pnpm_config_pm_on_fail=warn
  export npm_config_manage_package_manager_versions=false
fi

case "$cmd" in
  install)
    flags=$(install_flags)
    # Word splitting is intended: flags is a space-separated list.
    # shellcheck disable=SC2086
    case "$pm" in
      npm) run npm ci $flags ;;
      pnpm) run pnpm install --frozen-lockfile $flags ;;
      bun) run bun install --frozen-lockfile $flags ;;
    esac
    mkdir -p node_modules
    touch node_modules/.toolchain-install
    ;;
  run)
    [ $# -ge 1 ] || die "usage: pm.sh run <script> [args...]"
    run "$pm" run "$@"
    ;;
  run-if-present)
    for script in "$@"; do
      rc=0
      has_script "$script" || rc=$?
      case "$rc" in
        0) run "$pm" run "$script" ;;
        1) ;;
        *) exit "$rc" ;;
      esac
    done
    ;;
  *)
    die "unknown command '$cmd' (expected install, run or run-if-present)"
    ;;
esac
