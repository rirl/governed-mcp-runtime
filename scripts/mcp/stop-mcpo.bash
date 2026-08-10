#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ACCESS_MODE="${1:-}"

# shellcheck source=lib/governance.bash
source "${SCRIPT_DIR}/lib/governance.bash"

mcp_validate_stop_requirements() {
    local missing_count=0

    if ! command -v docker >/dev/null 2>&1; then
        echo "ERROR: required command unavailable: docker" >&2
        missing_count=$((missing_count + 1))
    fi

    if ! command -v curl >/dev/null 2>&1; then
        echo "ERROR: required command unavailable: curl" >&2
        missing_count=$((missing_count + 1))
    fi

    if [[ -z "${MCP_CONTAINER_NAME:-}" ]]; then
        echo "ERROR: required environment variable is missing: MCP_CONTAINER_NAME" >&2
        missing_count=$((missing_count + 1))
    fi

    if [[ -z "${MCP_HOST_PORT:-}" ]]; then
        echo "ERROR: required environment variable is missing: MCP_HOST_PORT" >&2
        missing_count=$((missing_count + 1))
    elif [[ ! "${MCP_HOST_PORT}" =~ ^[0-9]+$ ]] ||
        ((MCP_HOST_PORT < 1 || MCP_HOST_PORT > 65535)); then
        echo "ERROR: MCP_HOST_PORT must be an integer from 1 through 65535." >&2
        missing_count=$((missing_count + 1))
    fi

    if ((missing_count > 0)); then
        return 1
    fi
}

mcp_container_exists() {
    docker container inspect "${MCP_EFFECTIVE_CONTAINER_NAME}" \
        >/dev/null 2>&1
}

mcp_wait_for_container_absent() {
    local attempts="${1:-10}"
    local delay_seconds="${2:-1}"
    local attempt

    for ((attempt = 1; attempt <= attempts; attempt++)); do
        if ! mcp_container_exists; then
            printf 'PASS: container is absent: %s\n' \
                "${MCP_EFFECTIVE_CONTAINER_NAME}"
            return 0
        fi

        if ((attempt < attempts)); then
            sleep "${delay_seconds}"
        fi
    done

    printf 'FAIL: container still exists: %s\n' \
        "${MCP_EFFECTIVE_CONTAINER_NAME}" >&2
    return 1
}

mcp_wait_for_host_port_closed() {
    local attempts="${1:-10}"
    local delay_seconds="${2:-1}"
    local attempt
    local endpoint="http://127.0.0.1:${MCP_HOST_PORT}/"

    for ((attempt = 1; attempt <= attempts; attempt++)); do
        if ! curl \
            --silent \
            --max-time 1 \
            --output /dev/null \
            "${endpoint}" 2>/dev/null; then
            printf 'PASS: host port is closed: 127.0.0.1:%s\n' \
                "${MCP_HOST_PORT}"
            return 0
        fi

        if ((attempt < attempts)); then
            sleep "${delay_seconds}"
        fi
    done

    printf 'FAIL: host port remains open: 127.0.0.1:%s\n' \
        "${MCP_HOST_PORT}" >&2
    return 1
}

main() {
    mcp_validate_access_mode "${ACCESS_MODE}"
    mcp_validate_stop_requirements

    MCP_EFFECTIVE_CONTAINER_NAME="${MCP_CONTAINER_NAME}${MCP_ACCESS_SUFFIX}"

    printf 'Target container: %s\n' "${MCP_EFFECTIVE_CONTAINER_NAME}"

    if mcp_container_exists; then
        printf 'Stopping container: %s\n' "${MCP_EFFECTIVE_CONTAINER_NAME}"

        if ! docker stop "${MCP_EFFECTIVE_CONTAINER_NAME}" >/dev/null; then
            printf 'ERROR: failed to stop container: %s\n' \
                "${MCP_EFFECTIVE_CONTAINER_NAME}" >&2
            return 1
        fi
    else
        printf 'Container is already absent: %s\n' \
            "${MCP_EFFECTIVE_CONTAINER_NAME}"
    fi

    mcp_wait_for_container_absent 10 1
    mcp_wait_for_host_port_closed 10 1

}

main "$@"
