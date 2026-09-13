#!/usr/bin/env bash

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

mcp_run_runtime() {
    local image
    image="$(mcp_resolve_mcpo_runtime_image)"

    local api_key="${MCP_API_KEY:-}"
    local -a auth_options=()

    if [[ -n "${api_key}" ]]; then
        auth_options=(--api-key "${api_key}")
    else
        echo "WARNING: MCP_API_KEY is unset; MCPO will start without API-key authentication." >&2
        echo "The endpoint remains restricted to the local host binding." >&2
    fi

    docker run --rm -it \
        --name "${MCP_EFFECTIVE_CONTAINER_NAME}" \
        --user "${MCP_CONTAINER_USER}" \
        "${MCP_CONTAINER_OPTIONS[@]}" \
        --security-opt no-new-privileges:true \
        --cap-drop ALL \
        -p "127.0.0.1:${MCP_HOST_PORT}:${MCP_CONTAINER_PORT}" \
        -v "${MCP_PROJECT_PATH}:${MCP_CONTAINER_WORKSPACE}:${MCP_ACCESS_VOLUME}" \
        "${image}" \
        --host 0.0.0.0 \
        --port "${MCP_CONTAINER_PORT}" \
        "${auth_options[@]}" \
        -- \
        mcp-server-filesystem \
        "${MCP_CONTAINER_WORKSPACE}"
}
