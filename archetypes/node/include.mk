# Copyright 2026 BitWise Media Group Ltd
# SPDX-License-Identifier: MIT
#
# Make shim for the node archetype: consumer Makefiles say
#   include .mise/archetypes/node/include.mk
# The archetype adds no task names beyond the canonical set; the common
# forwarder does the rest.
_toolchain_dir := $(dir $(lastword $(MAKEFILE_LIST)))
include $(_toolchain_dir)../../common/include.mk
