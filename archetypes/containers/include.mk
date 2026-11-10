# Copyright 2026 BitWise Media Group Ltd
# SPDX-License-Identifier: MIT
#
# Make shim for the containers archetype: consumer Makefiles say
#   include .mise/archetypes/containers/include.mk
# It names the archetype's extra tasks (so a same-named file or directory can
# never shadow them) and pulls in the common forwarder, which does the rest.
# Make exports command-line variables to the forwarded mise run, so
# `make mirror-validate ENTRY=dex` selects the same way ENTRY=dex does.
MISE_TASKS += publish update-allowlists mirror-add mirror-check mirror-upgrade \
	mirror-validate mirror-lint mirror-publish
_toolchain_dir := $(dir $(lastword $(MAKEFILE_LIST)))
include $(_toolchain_dir)../../common/include.mk
