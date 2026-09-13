# MCP Runtime Pinning Checkpoint

Date: 2026-09-13

## Purpose

This checkpoint records the recovery and first reproducibility hardening pass for the governed MCP runtime used by the Awake in Omelas project.

The work began from recovery checkpoint `checkpoint-recover-091406`. The goal of this pass was to preserve the known-good runtime while identifying and pinning mutable dependencies before continuing KIOS/Omelas consolidation work.

## Execution environments

The recovered system spans two WSL2 Ubuntu environments:

- `Ubuntu-TF`
  - Terraform repository: `~/projects/terraform-openwebui`
  - Manages the OpenWebUI Docker container.
- `Ubuntu`
  - Runtime repository: `~/projects/governed-mcp-runtime`
  - Runs the governed MCP/MCPO filesystem runtime.
  - Omelas project path: `/home/landonr/projects/awake-in-omelas`.

## Recovery baseline

### OpenWebUI

Terraform detected that `open-webui-tf` had been deleted outside Terraform and proposed only its recreation:

- Plan: `1 to add, 0 to change, 0 to destroy`
- Container: `open-webui-tf`
- Published port: `3001 -> 8080`
- Persistent data: `/home/landonr/projects/openwebui-tf/data`
- Restart policy: `unless-stopped`
- Recovered image:
  `sha256:a26effeb220e132482bf7e0560b3404843e7bc40d23051144e062960df8df6b0`

Post-recovery validation:

- container running and healthy
- `GET http://127.0.0.1:3001/health` returned `{"status":true}`
- subsequent `terraform plan` reported no changes

### Governed MCP runtime

Recovered runtime:

- container: `Omelas-MCP-RW`
- image: `omelas/mcpo-filesystem:beta`
- host binding: `127.0.0.1:8765 -> 8000`
- OpenAPI title: `secure-filesystem-server`
- OpenAPI version: `0.2.0`
- runtime identity: `uid=1001 gid=1001`
- Omelas mount target: `/workspace/omelas`
- runtime repository branch: `feature/runtime-v0.2`
- recovery baseline commit before this change: `0243f43`

## Dependency inventory

The known-good runtime resolved the following versions:

| Component | Version / identity |
| --- | --- |
| Python | `3.11.2` |
| Node.js | `22.23.2` |
| npm | `10.9.8` |
| `mcpo` | `0.0.20` |
| Python MCP SDK | `1.28.1` |
| MCP filesystem server | `2026.8.31` |
| `ca-certificates` | `20250419~deb12u1` |
| `python3` | `3.11.2-1+b1` |
| `python3-minimal` | `3.11.2-1+b1` |

Existing Python constraints already pinned:

```text
mcpo==0.0.20
mcp==1.28.1
```

The recovered MCP image was:

```text
sha256:80f064fcc367810254e5c40fc779356cc60ccd24d766e14cda16123d79cc3f0a
```

The locally observed `mcp/filesystem:latest` image was:

```text
sha256:35fcf0217ca0d5bf7b0a5bd68fb3b89e08174676c0e0b4f431604512cf7b3f67
```

## Reproducibility gap

Two build inputs remained mutable:

1. Docker base image:

   ```dockerfile
   FROM node:22-bookworm-slim
   ```

2. Filesystem server installation:

   ```dockerfile
   npm install --global @modelcontextprotocol/server-filesystem
   ```

The Node 22.23.2 Bookworm Slim Linux/amd64 manifest was identified as:

```text
sha256:4d676821dff059fd00d277ee4261ef34ea712317fed0737c03941481b5760c96
```

## Pinning change

`docker/mcp/Dockerfile.mcpo-filesystem` was changed to use:

```dockerfile
FROM node:22.23.2-bookworm-slim@sha256:4d676821dff059fd00d277ee4261ef34ea712317fed0737c03941481b5760c96
```

and:

```dockerfile
npm install --global @modelcontextprotocol/server-filesystem@2026.8.31
```

No Debian package pinning was introduced in this pass.

## Candidate build and validation

The pinned candidate was built separately as:

```text
omelas/mcpo-filesystem:pinned-test
```

Candidate image digest:

```text
sha256:2a55c88be63cacce7942359808ccad34ef488f2d852d7ffb0fec8a9196868fa1
```

Its resolved versions matched the recovered runtime:

- Python `3.11.2`
- Node.js `22.23.2`
- npm `10.9.8`
- `mcpo==0.0.20`
- `mcp==1.28.1`
- `@modelcontextprotocol/server-filesystem@2026.8.31`

A disposable comparison runtime was started on `127.0.0.1:8766 -> 8000` while the recovered baseline remained active on port `8765`.

Behavioral comparison:

| Check | Baseline | Pinned candidate |
| --- | --- | --- |
| OpenAPI title | `secure-filesystem-server` | `secure-filesystem-server` |
| OpenAPI version | `0.2.0` | `0.2.0` |
| UID/GID | `1001:1001` | `1001:1001` |
| MCP transport | stdio | stdio |
| Target | `/workspace/omelas` | `/workspace/omelas` |
| MCPO listener | container port `8000` | container port `8000` |

The pinned candidate therefore matched the recovered baseline for the validation performed in this pass.

## Current boundary

This checkpoint establishes:

- recovery completed successfully
- recovered runtime preserved during testing
- first build-time pinning change validated
- no KIOS/Omelas extraction or consolidation change performed
- no Debian snapshot/package pinning performed
- no promotion of the pinned candidate to the normal runtime image reference performed yet

The next decision is how the governed launcher should reference the validated runtime image without relying on a mutable `:beta` tag.

## Diagram

See:

- `mcp-runtime-pinning-checkpoint.puml`
- `mcp-runtime-pinning-checkpoint.svg`
