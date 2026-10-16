#!/bin/bash
# Quick verification script for distgen integration

set -e

echo "=== Distgen Integration Verification ==="
echo

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

passed=0
failed=0
warned=0

check_pass() {
    echo -e "${GREEN}✓${NC} $1"
    ((passed++))
}

check_fail() {
    echo -e "${RED}✗${NC} $1"
    ((failed++))
}

check_warn() {
    echo -e "${YELLOW}⚠${NC} $1"
    ((warned++))
}

echo "1. Checking manifest files..."
if [ -f "manifest.yml" ] && [ -f "manifest-minimal.yml" ]; then
    check_pass "Manifest files exist"
else
    check_fail "Manifest files missing"
fi

echo
echo "2. Checking multispec configuration..."
if [ -f "specs/multispec.yml" ]; then
    check_pass "multispec.yml exists"

    # Check for distro definitions
    if grep -q "fedora43:" specs/multispec.yml; then
        check_pass "Fedora distro defined"
    else
        check_fail "Fedora distro not defined"
    fi

    if grep -q "rhel10:" specs/multispec.yml; then
        check_pass "RHEL10 distro defined"
    else
        check_fail "RHEL10 distro not defined"
    fi
else
    check_fail "multispec.yml missing"
fi

echo
echo "3. Checking template files..."
for template in "src/Dockerfile" "src/Dockerfile.minimal" "src/Dockerfile.minimal.fedora"; do
    if [ -f "$template" ]; then
        check_pass "$template exists"

        # Check for Jinja2 syntax
        if grep -q "{{ spec\." "$template"; then
            check_pass "$template has Jinja2 template variables"
        else
            check_warn "$template missing Jinja2 variables"
        fi
    else
        check_fail "$template missing"
    fi
done

echo
echo "4. Checking S2I scripts..."
for script in "assemble" "run" "run-minimal" "usage" "init-wrapper" "save-artifacts"; do
    if [ -f "src/s2i/bin/$script" ]; then
        check_pass "S2I script: $script"
    else
        check_fail "S2I script missing: $script"
    fi
done

echo
echo "5. Verifying C8S removal for v22 and v24..."
if [ ! -f "22/Dockerfile.c8s" ]; then
    check_pass "C8S removed from v22"
else
    check_fail "C8S still exists in v22 (should be removed)"
fi

if [ ! -f "24/Dockerfile.c8s" ]; then
    check_pass "C8S removed from v24"
else
    check_fail "C8S still exists in v24 (should be removed)"
fi

echo
echo "6. Verifying C9S and C10S support..."
if [ -f "22/Dockerfile.c9s" ]; then
    check_pass "C9S present for v22"
else
    check_fail "C9S missing for v22"
fi

if [ -f "22/Dockerfile.c10s" ]; then
    check_pass "C10S present for v22"
else
    check_fail "C10S missing for v22"
fi

echo
echo "7. Checking CNB environment variables..."
for version in 22 24; do
    for distro in fedora rhel8 rhel9; do
        dockerfile="$version/Dockerfile.$distro"
        if [ -f "$dockerfile" ]; then
            if grep -q "CNB_STACK_ID=" "$dockerfile"; then
                check_pass "CNB_STACK_ID in $version/$distro"
            else
                check_fail "CNB_STACK_ID missing in $version/$distro"
            fi

            if grep -q "CNB_USER_ID=" "$dockerfile"; then
                check_pass "CNB_USER_ID in $version/$distro"
            else
                check_fail "CNB_USER_ID missing in $version/$distro"
            fi
        fi
    done
done

echo
echo "8. Verifying distro-specific features..."

# Check Fedora uses versioned packages
if grep -q 'nodejs\$NODEJS_VERSION' 22/Dockerfile.fedora; then
    check_pass "Fedora uses versioned packages"
else
    check_fail "Fedora should use versioned packages (nodejs\$NODEJS_VERSION)"
fi

# Check RHEL8 uses gcc-toolset-13 for v22
if grep -q 'gcc-toolset-13' 22/Dockerfile.rhel8; then
    check_pass "RHEL8 v22 uses gcc-toolset-13"
else
    check_fail "RHEL8 v22 should use gcc-toolset-13"
fi

# Check Fedora uses versioned symlinks
if grep -q 'rm -f /usr/bin/node && ln -s /usr/bin/node-\$NODEJS_VERSION' 22/Dockerfile.fedora; then
    check_pass "Fedora uses versioned symlinks (rm -f before ln -s)"
else
    check_fail "Fedora should use 'rm -f' before creating symlinks"
fi

# Check RHEL8/9 use module enable
if grep -q 'module enable nodejs' 22/Dockerfile.rhel8; then
    check_pass "RHEL8 uses dnf module enable"
else
    check_fail "RHEL8 should use 'dnf module enable nodejs'"
fi

# Check Fedora base image is updated
if grep -q 'quay.io/fedora/s2i-core:44' 22/Dockerfile.fedora; then
    check_pass "Fedora base image is Fedora 44"
else
    check_warn "Fedora base image may not be updated to F44"
fi

echo
echo "9. Checking version matrix coverage..."
expected_v20=4  # rhel8, rhel9, c9s, fedora
expected_v22=6  # rhel8, rhel9, rhel10, c9s, c10s, fedora
expected_v24=6  # rhel8, rhel9, rhel10, c9s, c10s, fedora

actual_v20=$(ls 20/Dockerfile.* 2>/dev/null | wc -l)
actual_v22=$(ls 22/Dockerfile.* 2>/dev/null | wc -l)
actual_v24=$(ls 24/Dockerfile.* 2>/dev/null | wc -l)

if [ "$actual_v20" -eq "$expected_v20" ]; then
    check_pass "v20 has $expected_v20 distros"
else
    check_fail "v20 has $actual_v20 distros, expected $expected_v20"
fi

if [ "$actual_v22" -eq "$expected_v22" ]; then
    check_pass "v22 has $expected_v22 distros"
else
    check_fail "v22 has $actual_v22 distros, expected $expected_v22"
fi

if [ "$actual_v24" -eq "$expected_v24" ]; then
    check_pass "v24 has $expected_v24 distros"
else
    check_fail "v24 has $actual_v24 distros, expected $expected_v24"
fi

echo
echo "10. Checking for common submodule..."
if [ -d "common/.git" ] || [ -f "common/.git" ]; then
    check_pass "common submodule initialized"
else
    check_warn "common submodule not initialized (run: git submodule update --init)"
fi

echo
echo "=== Summary ==="
echo -e "${GREEN}Passed: $passed${NC}"
if [ $warned -gt 0 ]; then
    echo -e "${YELLOW}Warnings: $warned${NC}"
fi
if [ $failed -gt 0 ]; then
    echo -e "${RED}Failed: $failed${NC}"
    exit 1
else
    echo -e "\n${GREEN}All checks passed!${NC}"
    exit 0
fi
