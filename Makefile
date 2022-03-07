# Include common Makefile code.
BASE_IMAGE_NAME = nodejs
VERSIONS = 14 14-minimal 16 16-minimal
OPENSHIFT_NAMESPACES = 

# HACK:  Ensure that 'git pull' for old clones doesn't cause confusion.
# New clones should use '--recursive'.
.PHONY: $(shell test -f common/common.mk || echo >&2 'Please do "git submodule update --init" first.')

include common/common.mk
