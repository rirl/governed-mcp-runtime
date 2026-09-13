#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPOSITORY_ROOT="$(cd -- "${SCRIPT_DIR}/../.." && pwd)"

DOCKERFILE="${REPOSITORY_ROOT}/docker/mcp/Dockerfile.mcpo-filesystem"
BUILD_CONTEXT="${REPOSITORY_ROOT}"
IMAGE_NAME="${MCP_MCPO_BUILD_IMAGE:-${MCP_MCPO_IMAGE:-omelas/mcpo-filesystem:beta}}"

if [[ -n "${MCP_MCPO_IMAGE:-}" && -z "${MCP_MCPO_BUILD_IMAGE:-}" ]]; then
    echo "WARNING: MCP_MCPO_IMAGE is deprecated; use MCP_MCPO_BUILD_IMAGE for build output tagging." >&2
fi

BUILDER="$(docker buildx inspect --format '{{ .Name }}' 2>/dev/null || echo default)"

echo
echo "========================================"
echo " Governed MCP Runtime Build"
echo "========================================"
echo
printf "%-14s %s\n" "Repository:" "$REPOSITORY_ROOT"
printf "%-14s %s\n" "Dockerfile:" "$DOCKERFILE"
printf "%-14s %s\n" "Context   :" "$BUILD_CONTEXT"
printf "%-14s %s\n" "Builder   :" "$BUILDER"
printf "%-14s %s\n" "Image     :" "$IMAGE_NAME"
echo

exec docker buildx build \
    --load \
    --tag "${IMAGE_NAME}" \
    --file "${DOCKERFILE}" \
    "${BUILD_CONTEXT}"
