#!/usr/bin/env bash

mcp_run_runtime() {
    : "${MCP:?MCP must contain the filesystem MCP image name}"

    set -x
    docker run --rm -it \
        --name "${MCP_EFFECTIVE_CONTAINER_NAME}" \
        --user "${MCP_CONTAINER_USER}" \
        "${MCP_CONTAINER_OPTIONS[@]}" \
        --security-opt no-new-privileges:true \
        -p "127.0.0.1:${MCP_HOST_PORT}:${MCP_CONTAINER_PORT}" \
        -v "${MCP_PROJECT_PATH}:${MCP_CONTAINER_WORKSPACE}:${MCP_ACCESS_VOLUME}" \
        "${MCP}" \
        "${MCP_CONTAINER_WORKSPACE}"
    set +x
}
