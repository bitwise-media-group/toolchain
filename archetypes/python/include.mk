# Copyright 2026 BitWise Media Group Ltd
# SPDX-License-Identifier: MIT
#
# Make shim for the python archetype: consumer Makefiles say
#   include .mise/archetypes/python/include.mk
# It names the archetype's extra tasks (so a same-named file or directory can
# never shadow them) and pulls in the common forwarder, which does the rest.
MISE_TASKS += docs-build sync
_toolchain_dir := $(dir $(lastword $(MAKEFILE_LIST)))
include $(_toolchain_dir)../../common/include.mk
