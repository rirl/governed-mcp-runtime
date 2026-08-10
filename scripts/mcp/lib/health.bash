#!/usr/bin/env bash

readonly -a MCP_HEALTH_REQUIRED_COMMANDS=(
    curl
    docker
    git
)

mcp_validate_host_commands() {
    local command_name
    local missing_count=0

    for command_name in "${MCP_HEALTH_REQUIRED_COMMANDS[@]}"; do
        if command -v "${command_name}" >/dev/null 2>&1; then
            printf 'PASS: required command available: %s\n' "${command_name}"
        else
            printf 'FAIL: required command unavailable: %s\n' "${command_name}" >&2
            missing_count=$((missing_count + 1))
        fi
    done

    if ((missing_count > 0)); then
        echo "ERROR: ${missing_count} required command(s) are unavailable." >&2
        return 1
    fi
}

mcp_validate_container_running() {
    local container_name="${1:?container name is required}"
    local running

    running="$(
        docker inspect \
            --format '{{.State.Running}}' \
            "${container_name}" 2>/dev/null || true
    )"

    if [[ "${running}" != "true" ]]; then
        echo "FAIL: container is not running: ${container_name}" >&2
        return 1
    fi

    printf 'PASS: container is running: %s\n' "${container_name}"
}

mcp_wait_for_openapi() {
    local endpoint="${1:?OpenAPI endpoint is required}"
    local api_key="${2:?API key is required}"
    local attempts="${3:-10}"
    local delay_seconds="${4:-1}"
    local attempt
    local http_status

    for ((attempt = 1; attempt <= attempts; attempt++)); do
        http_status="$(
            curl \
                --silent \
                --show-error \
                --max-time 5 \
                --header "Authorization: Bearer ${api_key}" \
                --output /dev/null \
                --write-out '%{http_code}' \
                "${endpoint}" 2>/dev/null || true
        )"

        if [[ "${http_status}" == "200" ]]; then
            printf 'PASS: OpenAPI endpoint returned HTTP 200: %s\n' "${endpoint}"
            return 0
        fi

        if ((attempt < attempts)); then
            sleep "${delay_seconds}"
        fi
    done

    printf \
        'FAIL: OpenAPI endpoint did not return HTTP 200 after %d attempts: %s\n' \
        "${attempts}" \
        "${endpoint}" >&2
    return 1
}
