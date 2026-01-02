# Include common Makefile code.
BASE_IMAGE_NAME = nodejs
VERSIONS = 20 20-minimal 22 22-minimal 24 24-minimal
OPENSHIFT_NAMESPACES = 

# HACK:  Ensure that 'git pull' for old clones doesn't cause confusion.
# New clones should use '--recursive'.
.PHONY: $(shell test -f common/common.mk || echo >&2 'Please do "git submodule update --init" first.')

include common/common.mk

.PHONY: test-upstream
test-upstream: script_env += TEST_UPSTREAM=yes
test-upstream: tag
	VERSIONS="$(VERSIONS)" BASE_IMAGE_NAME="$(BASE_IMAGE_NAME)" $(script_env) common/test.sh
