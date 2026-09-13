#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ACCESS_MODE="${1:-}"
MCP_RUNTIME="mcpo"

# shellcheck source=lib/governance.bash
source "${SCRIPT_DIR}/lib/governance.bash"

# shellcheck source=lib/health.bash
source "${SCRIPT_DIR}/lib/health.bash"

mcp_resolve_mcpo_runtime_image() {
    if [[ -n "${MCP_MCPO_RUNTIME_IMAGE:-}" ]]; then
        printf '%s\n' "${MCP_MCPO_RUNTIME_IMAGE}"
        return 0
    fi

    if [[ -n "${MCP_MCPO_IMAGE:-}" ]]; then
        echo "WARNING: MCP_MCPO_IMAGE is deprecated; use MCP_MCPO_RUNTIME_IMAGE for runtime selection." >&2
        printf '%s\n' "${MCP_MCPO_IMAGE}"
        return 0
    fi

    printf '%s\n' "omelas/mcpo-filesystem@sha256:2a55c88be63cacce7942359808ccad34ef488f2d852d7ffb0fec8a9196868fa1"
}

mcp_validate_api_key() {
    if [[ -z "${MCP_API_KEY:-}" ]]; then
        echo "ERROR: MCP_API_KEY is required for the MCPO resume path." >&2
        return 1
    fi
}

mcp_validate_container_absent() {
    if docker container inspect \
        "${MCP_EFFECTIVE_CONTAINER_NAME}" >/dev/null 2>&1; then
        echo \
            "ERROR: container already exists: ${MCP_EFFECTIVE_CONTAINER_NAME}" \
            >&2
        return 1
    fi
}

mcp_start_detached_mcpo() {
    local image
    image="$(mcp_resolve_mcpo_runtime_image)"

    docker run --detach --rm \
        --name "${MCP_EFFECTIVE_CONTAINER_NAME}" \
        --user "${MCP_CONTAINER_USER}" \
        "${MCP_CONTAINER_OPTIONS[@]}" \
        --security-opt no-new-privileges:true \
        --cap-drop ALL \
        -p "127.0.0.1:${MCP_HOST_PORT}:${MCP_CONTAINER_PORT}" \
        -v \
        "${MCP_PROJECT_PATH}:${MCP_CONTAINER_WORKSPACE}:${MCP_ACCESS_VOLUME}" \
        "${image}" \
        --host 0.0.0.0 \
        --port "${MCP_CONTAINER_PORT}" \
        --api-key "${MCP_API_KEY}" \
        -- \
        mcp-server-filesystem \
        "${MCP_CONTAINER_WORKSPACE}"
}

mcp_cleanup_failed_start() {
    docker rm --force "${MCP_EFFECTIVE_CONTAINER_NAME}" >/dev/null 2>&1 || true
}

main() {
    local openapi_endpoint

    mcp_validate_host_commands
    mcp_validate_access_mode "${ACCESS_MODE}"
    mcp_validate_required_variables
    mcp_validate_api_key
    mcp_validate_repository_state "${ACCESS_MODE}"
    mcp_set_derived_values
    mcp_print_derived_values "${ACCESS_MODE}" "${MCP_RUNTIME}"
    mcp_validate_container_absent

    openapi_endpoint="http://127.0.0.1:${MCP_HOST_PORT}/openapi.json"

    echo "Starting detached MCPO runtime..."
    mcp_start_detached_mcpo

    if ! mcp_validate_container_running "${MCP_EFFECTIVE_CONTAINER_NAME}"; then
        mcp_cleanup_failed_start
        return 1
    fi

    if ! mcp_wait_for_openapi \
        "${openapi_endpoint}" \
        "${MCP_API_KEY}"; then
        echo "ERROR: MCPO startup validation failed; removing container." >&2
        mcp_cleanup_failed_start
        return 1
    fi

    echo
    printf 'MCPO runtime ready: %s\n' "${openapi_endpoint}"
    printf 'Container: %s\n' "${MCP_EFFECTIVE_CONTAINER_NAME}"
}

main "$@"
