# Copyright 2026 BitWise Media Group Ltd
# SPDX-License-Identifier: MIT
#
# Make shim for the swift archetype: consumer Makefiles say
#   include .mise/archetypes/swift/include.mk
# It names the archetype's extra tasks (so a same-named file or directory can
# never shadow them) and pulls in the common forwarder, which does the rest.
MISE_TASKS += resolve update snapshot release
_toolchain_dir := $(dir $(lastword $(MAKEFILE_LIST)))
include $(_toolchain_dir)../../common/include.mk
