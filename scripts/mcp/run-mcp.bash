#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ACCESS_MODE="${1:-}"
MCP_RUNTIME="${MCP_RUNTIME:-filesystem}"

# shellcheck source=lib/governance.bash
source "${SCRIPT_DIR}/lib/governance.bash"

load_runtime() {
    local runtime_path="${SCRIPT_DIR}/runtimes/${MCP_RUNTIME}.bash"

    if [[ ! -f "${runtime_path}" ]]; then
        echo "ERROR: unsupported MCP_RUNTIME: ${MCP_RUNTIME}" >&2
        echo "Expected a runtime file at: ${runtime_path}" >&2
        exit 1
    fi

    # shellcheck source=/dev/null
    source "${runtime_path}"

    if ! declare -F mcp_run_runtime >/dev/null; then
        echo "ERROR: runtime does not define mcp_run_runtime: ${runtime_path}" >&2
        exit 1
    fi
}

main() {
    mcp_validate_access_mode "${ACCESS_MODE}"
    mcp_validate_required_variables
    mcp_validate_repository_state "${ACCESS_MODE}"
    mcp_set_derived_values
    mcp_print_derived_values "${ACCESS_MODE}" "${MCP_RUNTIME}"
    load_runtime
    mcp_run_runtime
}

main "$@"
