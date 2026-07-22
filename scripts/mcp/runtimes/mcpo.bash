#!/usr/bin/env bash

mcp_run_runtime() {
    local image="${MCP_MCPO_IMAGE:-omelas/mcpo-filesystem:beta}"
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
