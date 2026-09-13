#!/usr/bin/env bash
set -euo pipefail

REPOSITORY_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
RUNTIME_SCRIPT="${REPOSITORY_ROOT}/scripts/mcp/runtimes/mcpo.bash"
BUILD_SCRIPT="${REPOSITORY_ROOT}/scripts/mcp/build-mcpo-filesystem.bash"

assert_eq() {
    local expected="$1"
    local actual="$2"
    local description="$3"

    if [[ "${expected}" != "${actual}" ]]; then
        printf 'not ok - %s\n' "${description}"
        printf '  expected: %s\n' "${expected}"
        printf '  actual:   %s\n' "${actual}"
        return 1
    fi

    printf 'ok - %s\n' "${description}"
}

resolve_runtime() {
    (
        unset MCP_MCPO_RUNTIME_IMAGE MCP_MCPO_IMAGE
        # shellcheck source=/dev/null
        source "${RUNTIME_SCRIPT}"
        mcp_resolve_mcpo_runtime_image
    )
}

resolve_runtime_override() {
    (
        export MCP_MCPO_RUNTIME_IMAGE="example/runtime:explicit"
        unset MCP_MCPO_IMAGE
        # shellcheck source=/dev/null
        source "${RUNTIME_SCRIPT}"
        mcp_resolve_mcpo_runtime_image
    )
}

resolve_compat_override() {
    (
        unset MCP_MCPO_RUNTIME_IMAGE
        export MCP_MCPO_IMAGE="example/runtime:legacy"
        # shellcheck source=/dev/null
        source "${RUNTIME_SCRIPT}"
        mcp_resolve_mcpo_runtime_image 2>/dev/null
    )
}

default_runtime="$(resolve_runtime)"
explicit_runtime="$(resolve_runtime_override)"
compat_runtime="$(resolve_compat_override)"

assert_eq "omelas/mcpo-filesystem@sha256:2a55c88be63cacce7942359808ccad34ef488f2d852d7ffb0fec8a9196868fa1" "${default_runtime}"     "default runtime image is immutable validated digest"
assert_eq "example/runtime:explicit" "${explicit_runtime}"     "MCP_MCPO_RUNTIME_IMAGE overrides runtime default"
assert_eq "example/runtime:legacy" "${compat_runtime}"     "legacy MCP_MCPO_IMAGE runtime override remains compatible"

if ! grep -q 'MCP_MCPO_BUILD_IMAGE' "${BUILD_SCRIPT}"; then
    echo "not ok - build script supports MCP_MCPO_BUILD_IMAGE"
    exit 1
fi
echo "ok - build script supports MCP_MCPO_BUILD_IMAGE"

if ! grep -q 'MCP_MCPO_IMAGE' "${BUILD_SCRIPT}"; then
    echo "not ok - build script keeps legacy MCP_MCPO_IMAGE compatibility"
    exit 1
fi
echo "ok - build script keeps legacy MCP_MCPO_IMAGE compatibility"
