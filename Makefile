# Include common Makefile code.
BASE_IMAGE_NAME = nodejs
VERSIONS = 4 6
OPENSHIFT_NAMESPACES = 0.10

# HACK:  Ensure that 'git pull' for old clones doesn't cause confusion.
# New clones should use '--recursive'.
.PHONY: $(shell test -f common/common.mk || echo >&2 'Please do "git submodule update --init" first.')

include common/common.mk
