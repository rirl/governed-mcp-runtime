# MCP Runtime Registry Recovery Validation

Date: 2026-09-13

## Purpose

This checkpoint records the registry-durability and recovery acceptance test for the governed MCP runtime used by the Awake in Omelas project.

The earlier runtime-pinning and image-selection checkpoints established a reproducible candidate image and made runtime selection depend on an immutable image digest rather than the mutable `:beta` build tag.

This validation answers the remaining recovery question:

> Can the validated governed MCP runtime be recovered after the local Docker image is lost, using only an authenticated external registry and the immutable image identity?

The answer from this test is yes.

## Scope

This validation is limited to recovery hardening.

It does not perform:

- KIOS/Omelas consolidation
- architectural extraction or separation
- CI publication automation
- transitive dependency pinning
- repository-manager integration
- image-signing or SBOM policy enforcement

## Validated runtime identity

Validated image:

```text
sha256:2a55c88be63cacce7942359808ccad34ef488f2d852d7ffb0fec8a9196868fa1
```

Private GHCR repository:

```text
ghcr.io/rirl/governed-mcp-runtime
```

Bootstrap publication tag:

```text
ghcr.io/rirl/governed-mcp-runtime:validated-2026-09-13
```

Immutable recovery reference:

```text
ghcr.io/rirl/governed-mcp-runtime@sha256:2a55c88be63cacce7942359808ccad34ef488f2d852d7ffb0fec8a9196868fa1
```

The package is intentionally private. Registry access requires authentication.

## Pre-validation findings

The runtime build path was confirmed to be local-only:

```text
docker buildx build --load
```

No existing registry push, OCI export, or Docker image export mechanism was present.

The validated image therefore existed only in the local Docker image store before this checkpoint.

The runtime image itself contained no OCI repository labels.

Further transitive pinning was evaluated but classified as deferred because the already-validated runtime artifact could instead be preserved directly by immutable digest.

## GHCR publication

The already-validated image was tagged for GHCR without rebuilding it.

Before publication:

```text
Local image ID:
sha256:2a55c88be63cacce7942359808ccad34ef488f2d852d7ffb0fec8a9196868fa1
```

The image was pushed to the private GHCR repository.

GHCR reported:

```text
validated-2026-09-13:
digest: sha256:2a55c88be63cacce7942359808ccad34ef488f2d852d7ffb0fec8a9196868fa1
```

The registry digest therefore matched the validated image identity exactly.

Docker authentication was removed after publication.

## Recovery acceptance test

The recovery test was performed in four phases.

### Phase 1 — authenticated remote availability

The local image remained present while authenticated remote availability was tested.

GHCR authentication succeeded.

The immutable remote reference resolved successfully:

```text
Name:
ghcr.io/rirl/governed-mcp-runtime@sha256:2a55c88be63cacce7942359808ccad34ef488f2d852d7ffb0fec8a9196868fa1

MediaType:
application/vnd.oci.image.index.v1+json

Digest:
sha256:2a55c88be63cacce7942359808ccad34ef488f2d852d7ffb0fec8a9196868fa1
```

The image index contained:

```text
Platform: linux/amd64
```

and an associated attestation manifest.

Result:

```text
PASS
```

The remote registry could serve the exact immutable image identity when authenticated.

### Phase 2 — local image loss simulation

Before deletion, Docker confirmed that no container referenced the validated image.

The local references:

```text
omelas/mcpo-filesystem:pinned-test
ghcr.io/rirl/governed-mcp-runtime:validated-2026-09-13
```

were removed.

The underlying image object:

```text
sha256:2a55c88be63cacce7942359808ccad34ef488f2d852d7ffb0fec8a9196868fa1
```

was then verified absent from the local Docker image store.

The separate mutable build artifact remained:

```text
omelas/mcpo-filesystem:beta
sha256:048f49ba6db14cf4a81b260373aae6557f8b32f4c814cec87d20aa41b45bc28d
```

Result:

```text
PASS
```

The test environment now represented loss of the validated local runtime image.

### Phase 3 — authenticated recovery by immutable digest

Docker authenticated to GHCR and pulled:

```text
ghcr.io/rirl/governed-mcp-runtime@sha256:2a55c88be63cacce7942359808ccad34ef488f2d852d7ffb0fec8a9196868fa1
```

The pull reported:

```text
Digest:
sha256:2a55c88be63cacce7942359808ccad34ef488f2d852d7ffb0fec8a9196868fa1
```

The restored image ID was compared directly with the expected validated image ID:

```text
expected=sha256:2a55c88be63cacce7942359808ccad34ef488f2d852d7ffb0fec8a9196868fa1
actual=sha256:2a55c88be63cacce7942359808ccad34ef488f2d852d7ffb0fec8a9196868fa1
```

Result:

```text
PASS
```

The exact validated image was recovered from the authenticated external registry after the local copy had been removed.

### Phase 4 — governed runtime recovery

The recovered GHCR image was selected explicitly:

```text
MCP_MCPO_RUNTIME_IMAGE=
ghcr.io/rirl/governed-mcp-runtime@sha256:2a55c88be63cacce7942359808ccad34ef488f2d852d7ffb0fec8a9196868fa1
```

The first resume attempt correctly failed before container creation because `ACCESS_MODE` is a required positional argument.

Repository inspection confirmed that the governed interface is:

```text
resume-mcpo.bash readonly
```

or:

```text
resume-mcpo.bash readwrite
```

For the Omelas read-write runtime, the validated invocation was:

```text
bash ./scripts/mcp/resume-mcpo.bash readwrite
```

The governance layer validated:

```text
MCP_PROJECT_PATH:
  /home/landonr/projects/awake-in-omelas

MCP_PROJECT_BRANCH:
  feature/openwebui-mcp-filesystem

ACCESS_MODE:
  readwrite

MCP_ACCESS_SUFFIX:
  RW

MCP_ACCESS_VOLUME:
  rw

MCP_CONTAINER_USER:
  1001:1001

MCP_EFFECTIVE_CONTAINER_NAME:
  Omelas-MCP-RW
```

The governed resume succeeded.

Observed runtime:

```text
Container:
Omelas-MCP-RW

Status:
running

Image reference:
ghcr.io/rirl/governed-mcp-runtime@sha256:2a55c88be63cacce7942359808ccad34ef488f2d852d7ffb0fec8a9196868fa1

Image ID:
sha256:2a55c88be63cacce7942359808ccad34ef488f2d852d7ffb0fec8a9196868fa1

Runtime user:
1001:1001

Host binding:
127.0.0.1:8765 -> 8000
```

Authenticated OpenAPI validation returned:

```text
title=secure-filesystem-server
version=0.2.0
```

Result:

```text
PASS
```

The runtime was therefore recovered from the registry artifact through the normal governed resume path.

## What was learned

### Local `RepoDigests` do not prove external durability

A local Docker image may contain a digest reference without proving that the image is retrievable from an external registry.

Remote authenticated inspection and subsequent deletion-and-pull testing were required to establish durable recovery.

### Exact artifact preservation was possible

The validated runtime artifact was published without rebuilding it.

The image digest before publication, in GHCR, and after registry recovery remained:

```text
sha256:2a55c88be63cacce7942359808ccad34ef488f2d852d7ffb0fec8a9196868fa1
```

The recovery test therefore exercised the exact artifact previously validated rather than a newly rebuilt equivalent.

### Private registry access is compatible with recovery

Anonymous GHCR inspection returned HTTP 401.

Authenticated registry access succeeded.

Private, authenticated image retrieval is therefore compatible with the governed recovery model and is preferred for this environment.

### Build and runtime image identities remain separate

The mutable build destination:

```text
omelas/mcpo-filesystem:beta
```

remained a separate image from the validated runtime artifact.

The runtime recovery path selected the immutable GHCR digest explicitly.

This confirms that the build tag is not the runtime trust boundary.

### `ACCESS_MODE` is part of the governed interface

`ACCESS_MODE` is not an environment variable consumed implicitly by the resume command.

It is a positional launcher argument:

```text
readonly
readwrite
```

For read-write operation, the governance layer derives:

```text
MCP_CONTAINER_NAME=Omelas-MCP-
        +
MCP_ACCESS_SUFFIX=RW
        =
Omelas-MCP-RW
```

The configured `MCP_CONTAINER_NAME` value is therefore intentionally a prefix.

### `MCP_PROJECT_PATH` is the governed project variable

The runtime contract requires:

```text
MCP_PROJECT_PATH
```

not `MCP_TARGET_PROJECT`.

For this runtime:

```text
MCP_PROJECT_PATH=/home/landonr/projects/awake-in-omelas
```

### Remaining dependency hardening is not a consolidation blocker

The following items remain useful future hardening work but are not required for reproducible recovery of the validated runtime artifact:

- explicit `uvicorn` pinning
- explicit `fastapi` pinning
- Python patch-version pinning
- Debian package snapshotting
- OCI source/revision labels
- automated GHCR publication
- SBOM generation and enforcement
- image signing
- centralized Nexus/Artifactory ingress
- approved-image policy enforcement

These items are classified as deferred.

## Result

The registry-recovery hardening checkpoint is validated end to end:

- validated runtime artifact published to private GHCR
- registry access requires authentication
- remote immutable digest verified
- local validated image deliberately removed
- local loss confirmed
- exact image recovered by authenticated immutable-digest pull
- recovered image ID matched the original validated artifact
- governed read-write resume succeeded
- runtime identity remained `1001:1001`
- local-only host binding remained `127.0.0.1:8765 -> 8000`
- authenticated OpenAPI remained functional
- service identity remained `secure-filesystem-server` version `0.2.0`
- no KIOS/Omelas consolidation or architectural-refactoring work was performed

## Current boundary

Recovery and immediate reproducibility hardening are now sufficient to resume the KIOS/Omelas consolidation path.

There are no remaining blocking MCP runtime dependency or artifact-durability issues identified by this checkpoint.

Deferred runtime hardening should remain separate from consolidation unless a later requirement makes one of those items a prerequisite.

The next program-control step is to:

1. reconcile the live Git state of the Omelas and program-control repositories
2. establish and validate the `development` parking baseline
3. decide and record the integration method for:

   ```text
   feature/openwebui-mcp-filesystem -> development
   ```

No extraction or further architectural separation should begin before that control point is established.
