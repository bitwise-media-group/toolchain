# Copyright 2026 BitWise Media Group Ltd
# SPDX-License-Identifier: MIT
#
# common/include.mk — the whole make surface, forwarded to mise tasks.
#
# Consumer Makefiles include ONE of this library's shims and stay thin:
#   include .mise/common/include.mk            # common-only (markdown/yaml) repo
#   include .mise/archetypes/<lang>/include.mk # a language archetype (includes this file)
# The canonical lint/build/test/e2e contract the reusable CI runs, plus
# fmt/ci/pr/help/commit and every archetype extra, are mise tasks defined by
# this library (common/tasks.toml + archetypes/<lang>/tasks.toml, included
# from the consumer's root mise.toml) with the pinned tools from
# config.toml/mise.lock on PATH inside each task — no .bin/, no tool-path
# plumbing. Extension still works both ways:
#   - make-side:  `pr: docs` adds a prerequisite (runs BEFORE `mise run pr`);
#   - mise-side:  add or redefine tasks in the repo's root mise.toml [tasks]
#     (task merging is whole-task replacement, so a redefinition wins).
ifndef MK_MISE_INCLUDED
MK_MISE_INCLUDED := 1

# Overridable for testing or a pinned mise binary.
MISE ?= mise

define require_mise
command -v $(MISE) >/dev/null 2>&1 \
	|| { echo "make: mise is required (https://mise.jdx.dev -- brew install mise)" >&2; exit 1; }
endef

# Serial make preserves `make fmt lint` command-line ordering and keeps two mise
# invocations from racing first-time tool installs; ordering *within* a target
# and any parallelism live inside mise now.
.NOTPARALLEL:

# No built-in suffix rules: nothing here builds files, and an implicit rule must
# not intercept a target name before the .DEFAULT forwarder below sees it.
.SUFFIXES:

.DEFAULT_GOAL := help

# Every well-known task is declared .PHONY and forwarded explicitly so a file or
# directory with the same name (docs/, coverage/, dist/) can never shadow it —
# make would otherwise report "'docs' is up to date" and never invoke mise.
# `+=` so an archetype include.mk can add its own names before including this
# file; the rule below is expanded at this point, so names appended AFTER the
# include still forward, but only via the .DEFAULT catch-all.
MISE_TASKS += lint build test e2e fmt ci pr commit license docs serve \
	actionlint zizmor

.PHONY: $(MISE_TASKS) help
$(MISE_TASKS):
	@ $(require_mise); $(MISE) run $@

help: ## list available tasks
	@ $(require_mise); $(MISE) tasks

# Catch-all: any other target name forwards to a same-named mise task, so
# repo-local tasks work as `make <task>` without ever editing this file. An
# unknown name gets mise's "no task" error instead of make's "No rule to make
# target" — an accepted trade.
.DEFAULT:
	@ $(require_mise); $(MISE) run $@

endif
