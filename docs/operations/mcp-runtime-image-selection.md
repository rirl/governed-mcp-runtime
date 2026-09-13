# MCP Runtime Image Selection

## Runtime image-selection hardening

A second reproducibility pass separates the image name used when building from the immutable image selected at runtime.

### Build selection

`MCP_MCPO_BUILD_IMAGE` now controls the image tag produced by `build-mcpo-filesystem.bash`.

Default:

```text
omelas/mcpo-filesystem:beta
```

For compatibility, the older `MCP_MCPO_IMAGE` variable is still accepted when `MCP_MCPO_BUILD_IMAGE` is unset, but emits a deprecation warning.

### Runtime selection

`MCP_MCPO_RUNTIME_IMAGE` now controls the image executed by the interactive and resume MCPO launchers.

Default validated runtime:

```text
omelas/mcpo-filesystem@sha256:2a55c88be63cacce7942359808ccad34ef488f2d852d7ffb0fec8a9196868fa1
```

This reference was verified locally with `docker image inspect` before being adopted.

For compatibility, `MCP_MCPO_IMAGE` remains a fallback runtime override when `MCP_MCPO_RUNTIME_IMAGE` is unset, but emits a deprecation warning.

### Selection precedence

Runtime:

```text
MCP_MCPO_RUNTIME_IMAGE
        ↓
MCP_MCPO_IMAGE (deprecated compatibility override)
        ↓
validated immutable digest
```

Build:

```text
MCP_MCPO_BUILD_IMAGE
        ↓
MCP_MCPO_IMAGE (deprecated compatibility override)
        ↓
omelas/mcpo-filesystem:beta
```

This deliberately separates the mutable build destination from the immutable runtime identity.
