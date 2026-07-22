#!/usr/bin/env bash

readonly -a MCP_REQUIRED_VARIABLES=(
    MCP_CONTAINER_NAME
    MCP_CONTAINER_PORT
    MCP_CONTAINER_WORKSPACE
    MCP_HOST_PORT
    MCP_PROJECT_PATH
)

mcp_validate_access_mode() {
    local access_mode="${1:-}"

    case "${access_mode}" in
        readonly)
            MCP_ACCESS_SUFFIX="RO"
            MCP_ACCESS_VOLUME="ro"
            MCP_CONTAINER_OPTIONS=(--read-only)
            ;;
        readwrite)
            MCP_ACCESS_SUFFIX="RW"
            MCP_ACCESS_VOLUME="rw"
            MCP_CONTAINER_OPTIONS=()
            ;;
        "")
            echo "missing, null, or empty argument: ACCESS_MODE" >&2
            echo "expected exactly one of: readonly, readwrite" >&2
            return 1
            ;;
        *)
            echo "invalid ACCESS_MODE: ${access_mode}" >&2
            echo "expected exactly one of: readonly, readwrite" >&2
            return 1
            ;;
    esac
}

mcp_validate_required_variables() {
    local missing_count=0
    local variable_name
    local variable_value
    local -a required_variables

    mapfile -t required_variables < <(
        printf '%s\n' "${MCP_REQUIRED_VARIABLES[@]}" | sort
    )

    echo
    echo "Required environment variables"
    echo "=============================="
    echo

    for variable_name in "${required_variables[@]}"; do
        variable_value="${!variable_name:-}"

        if [[ -z "${variable_value}" ]]; then
            printf '%-32s : MISSING\n' "${variable_name}"
            missing_count=$((missing_count + 1))
        else
            printf '%-32s : %s\n' "${variable_name}" "${variable_value}"
        fi
    done

    echo

    if ((missing_count > 0)); then
        echo "ERROR: ${missing_count} required environment variable(s) are missing." >&2
        return 1
    fi
}

mcp_validate_repository_state() {
    local access_mode="${1:?ACCESS_MODE is required}"
    local current_branch

    if [[ ! -d "${MCP_PROJECT_PATH}" ]]; then
        echo "ERROR: MCP_PROJECT_PATH does not exist: ${MCP_PROJECT_PATH}" >&2
        return 1
    fi

    if ! git -C "${MCP_PROJECT_PATH}" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        echo "ERROR: MCP_PROJECT_PATH is not a Git repository: ${MCP_PROJECT_PATH}" >&2
        return 1
    fi

    if ! current_branch="$(
        git -C "${MCP_PROJECT_PATH}" symbolic-ref --quiet --short HEAD
    )"; then
        echo "ERROR: repository HEAD is detached: ${MCP_PROJECT_PATH}" >&2
        return 1
    fi

    if [[ "${access_mode}" == "readwrite" ]]; then
        if [[ "${current_branch}" != feature/* ]]; then
            echo "ERROR: read-write access requires a feature/* branch." >&2
            echo "Current branch: ${current_branch}" >&2
            return 1
        fi

        if [[ -n "$(git -C "${MCP_PROJECT_PATH}" status --porcelain)" ]]; then
            echo "ERROR: read-write access requires a clean working tree." >&2
            return 1
        fi
    fi

    MCP_PROJECT_BRANCH="${current_branch}"
    printf '%-32s : %s\n' "MCP_PROJECT_BRANCH" "${MCP_PROJECT_BRANCH}"
}

mcp_set_derived_values() {
    local project_uid
    local project_gid

    project_uid="$(stat --format='%u' "${MCP_PROJECT_PATH}")"
    project_gid="$(stat --format='%g' "${MCP_PROJECT_PATH}")"

    MCP_EFFECTIVE_CONTAINER_NAME="${MCP_CONTAINER_NAME}${MCP_ACCESS_SUFFIX}"
    MCP_PROJECT_UID="${project_uid}"
    MCP_PROJECT_GID="${project_gid}"
    MCP_CONTAINER_USER="${MCP_PROJECT_UID}:${MCP_PROJECT_GID}"
}

mcp_print_derived_values() {
    local access_mode="${1:?ACCESS_MODE is required}"
    local runtime="${2:?runtime is required}"

    echo
    echo "Derived values"
    echo "=============="
    echo

    printf '%-32s : %s\n' "ACCESS_MODE" "${access_mode}"
    printf '%-32s : %s\n' "MCP_RUNTIME" "${runtime}"
    printf '%-32s : %s\n' "MCP_ACCESS_SUFFIX" "${MCP_ACCESS_SUFFIX}"
    printf '%-32s : %s\n' "MCP_ACCESS_VOLUME" "${MCP_ACCESS_VOLUME}"
    printf '%-32s : %s\n' "MCP_CONTAINER_USER" "${MCP_CONTAINER_USER}"

    if ((${#MCP_CONTAINER_OPTIONS[@]} == 0)); then
        printf '%-32s : %s\n' "MCP_CONTAINER_OPTIONS" "none"
    else
        printf '%-32s : %s\n' "MCP_CONTAINER_OPTIONS" "${MCP_CONTAINER_OPTIONS[*]}"
    fi

    printf '%-32s : %s\n' "MCP_EFFECTIVE_CONTAINER_NAME" "${MCP_EFFECTIVE_CONTAINER_NAME}"
    echo
}
