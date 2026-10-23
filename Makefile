# The toolchain library dogfoods its own tasks: common plus the python
# archetype (for the docs site), wired via the root mise.toml (see the comment
# there for why the layout is inverted relative to consumers, whose Makefiles
# say `include .mise/common/include.mk` or
# `include .mise/archetypes/<lang>/include.mk`).
include archetypes/python/include.mk

# shellcheck this library's own task scripts — a make-side prerequisite
# extension (it runs `mise run lint-scripts` via the .DEFAULT forwarder before
# `mise run lint`).
lint: lint-scripts
