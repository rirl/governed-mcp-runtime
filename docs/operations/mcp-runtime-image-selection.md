# MCP Runtime Image Selection

Date: 2026-09-13

## Purpose

This checkpoint records the second reproducibility-hardening pass for the governed MCP runtime used by the Awake in Omelas project.

The first pinning pass made the runtime build more reproducible by pinning the Node.js base image, `mcpo==0.0.20`, `mcp==1.28.1`, and `@modelcontextprotocol/server-filesystem@2026.8.31`.

This second pass separates the mutable image name used as a build destination from the immutable image identity selected at runtime.

## Build image selection

`MCP_MCPO_BUILD_IMAGE` controls the tag written by `scripts/mcp/build-mcpo-filesystem.bash`.

Default:

```text
omelas/mcpo-filesystem:beta
```

Compatibility precedence:

```text
MCP_MCPO_BUILD_IMAGE
        ↓
MCP_MCPO_IMAGE (deprecated)
        ↓
omelas/mcpo-filesystem:beta
```

## Runtime image selection

`MCP_MCPO_RUNTIME_IMAGE` controls the image executed by `scripts/mcp/runtimes/mcpo.bash` and `scripts/mcp/resume-mcpo.bash`.

Validated default runtime:

```text
omelas/mcpo-filesystem@sha256:2a55c88be63cacce7942359808ccad34ef488f2d852d7ffb0fec8a9196868fa1
```

Runtime precedence:

```text
MCP_MCPO_RUNTIME_IMAGE
        ↓
MCP_MCPO_IMAGE (deprecated)
        ↓
validated immutable digest
```

## Why the split exists

A mutable tag such as `omelas/mcpo-filesystem:beta` is useful as a build destination, but it is not a stable runtime trust boundary because it can later point at different image content.

The runtime therefore defaults to the validated content-addressed image reference above.

## Test coverage

`tests/mcp/image-selection.bash` passed:

```text
ok - default runtime image is immutable validated digest
ok - MCP_MCPO_RUNTIME_IMAGE overrides runtime default
ok - legacy MCP_MCPO_IMAGE runtime override remains compatible
ok - build script supports MCP_MCPO_BUILD_IMAGE
ok - build script keeps legacy MCP_MCPO_IMAGE compatibility
```

## Credential provenance correction: `MCP_API_KEY`

During validation, the provenance of `MCP_API_KEY` was investigated because the local environment had at one point assigned it from `OPENAI_API_KEY` merely to ensure that it was non-empty.

That created a misleading configuration:

```bash
export MCP_API_KEY="${OPENAI_API_KEY}"
```

Repository documentation and runtime behavior show that `MCP_API_KEY` is not an OpenAI provider credential. It is the local bearer token used by MCPO itself:

```text
MCPO server:
    --api-key <local-token>

MCPO client / health check:
    Authorization: Bearer <local-token>
```

The earlier Beta breakpoint documentation explicitly described it as:

```text
export MCP_API_KEY='replace-with-a-local-development-key'
```

The confusion was therefore a credential-provenance and naming issue, not a change introduced by the image-selection refactor.

The local configuration was corrected by generating a separate random token and assigning that stable value to `MCP_API_KEY`. `OPENAI_API_KEY` is no longer reused for MCPO authentication.

No runtime script interface change was required for this correction.

### Terminology note

The current code and documentation use the variable name `MCP_API_KEY`. References to an `MCP_API_TOKEN` during troubleshooting were informal shorthand and do not refer to a separate configured variable.

## End-to-end governed restart validation

After the image-selection tests passed and the MCPO bearer-token provenance was corrected, the governed MCP runtime was stopped and restarted through the normal resume path.

Observed runtime:

```text
Container: Omelas-MCP-RW
Host binding: 127.0.0.1:8765 -> 8000
Image reference: omelas/mcpo-filesystem@sha256:2a55c88be63cacce7942359808ccad34ef488f2d852d7ffb0fec8a9196868fa1
Image ID: sha256:2a55c88be63cacce7942359808ccad34ef488f2d852d7ffb0fec8a9196868fa1
```

Authenticated OpenAPI validation returned:

```json
{
  "title": "secure-filesystem-server",
  "version": "0.2.0"
}
```

This proves that the real governed restart path selected the exact immutable image identity rather than the mutable `:beta` tag and that the independently generated local MCPO bearer token authenticated successfully.

## Result

The second hardening pass is validated end to end:

- build and runtime image-selection concerns are separated
- runtime defaults to the exact validated image digest
- compatibility with the old `MCP_MCPO_IMAGE` override is retained
- image-selection behavior is tested
- a real governed restart selected the immutable image successfully
- authenticated OpenAPI access remained functional
- `MCP_API_KEY` provenance was corrected and documented
- OpenAI and MCPO authentication credentials are now separated locally

## Current boundary

This checkpoint does not yet:

- publish the image to an external registry
- remove the deprecated `MCP_MCPO_IMAGE` path
- rename `MCP_API_KEY`
- pin Debian repositories or snapshot dates
- change KIOS/Omelas consolidation boundaries
