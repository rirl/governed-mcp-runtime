#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPOSITORY_ROOT="$(cd -- "${SCRIPT_DIR}/../.." && pwd)"
IMAGE_NAME="${MCP_MCPO_IMAGE:-omelas/mcpo-filesystem:beta}"

exec docker build \
    --tag "${IMAGE_NAME}" \
    --file "${REPOSITORY_ROOT}/docker/mcp/Dockerfile.mcpo-filesystem" \
    "${REPOSITORY_ROOT}/docker/mcp"
