# docker-pebble-sdk — Specification

## Overview

`docker-pebble-sdk` provides a maintained, multi-architecture Docker image for building Pebble smartwatch applications using the current `pebble-tool` from Core Devices (the team behind the Pebble revival, led by original Pebble founder Eric Migicovsky). Every existing Pebble Docker image on Docker Hub (`rebble/pebble-sdk`, `bboehmke/pebble-dev`, etc.) was last updated over 5 years ago, targets SDK 4.5, bundles Python 2 tooling, and is incompatible with the modern `uv`-based install path documented at [developer.repebble.com](https://developer.repebble.com/sdk/). This image fills that gap: it installs `pebble-tool` via `uv` exactly as the official docs prescribe, bakes in the latest Pebble SDK, and is rebuilt automatically each time either `pebble-tool` or the SDK releases a new version.

## What's Inside

| Component | Version / Source | Purpose |
|---|---|---|
| Base OS | `debian:bookworm-slim` | Stable, minimal glibc base |
| Python | 3.13 (uv-managed) | pebble-tool runtime |
| uv | latest stable | Python toolchain + pebble-tool install |
| pebble-tool | latest PyPI (`coredevices/pebble-tool`) | Pebble build, emulator, install |
| Pebble SDK | latest (`pebble sdk install latest`) | SDK headers, firmware, resources |
| ARM cross-toolchain | `gcc-arm-none-eabi` (fetched by pebble-tool) | Compiles C watchapps |
| Node.js | LTS (via NodeSource) + npm | Webpack bundling for multi-JS apps |
| gcc / make / libc-dev | system apt | Host unit tests (Unity etc.) |
| QEMU | bundled in pebble-tool | Basalt emulator |
| SDL2 runtime libs | `libsdl2-2.0-0` | Headless emulator display |
| ImageMagick | `imagemagick` | Screenshot post-processing |
| pytest | via pip inside uv venv | e2e harness |
| libpebble2 | bundled with pebble-tool uv install | pebble2 Python protocol library |

Exact versions baked into each image release are recorded in the OCI labels (see §Image Labels) and in the `versions.env` file at the repo root.

## Image Tags

All tags are published as a multi-arch manifest list to both registries:

| Tag | Meaning |
|---|---|
| `latest` | Most recent release |
| `pebble-tool-<x.y.z>` | Exact pebble-tool version |
| `sdk-<x.y.z>` | Exact Pebble SDK version |
| `pebble-tool-<x.y.z>-sdk-<a.b.c>` | Both pinned (canonical stable tag) |
| `<git-sha>` | Exact build provenance |

Registries:
- `ghcr.io/gregolsky/pebble-sdk`
- `docker.io/gregolsky/pebble-sdk`

## Architectures

Images are built with `docker buildx` as a single manifest list:

- `linux/amd64` — x86 Linux, standard CI runners
- `linux/arm64` — Apple Silicon (native, no Rosetta), ARM Linux

The ARM cross-toolchain (`arm-none-eabi`) is a cross-compiler present on both host architectures — it builds for the Pebble MCU regardless of the host arch.

## Usage

### Build a `.pbw` in one shot

```bash
docker run --rm \
  -v "$PWD":/work -w /work \
  ghcr.io/gregolsky/pebble-sdk:latest \
  pebble build
```

### Headless emulator + install

```bash
docker run --rm \
  -e SDL_VIDEODRIVER=dummy \
  -e SDL_AUDIODRIVER=dummy \
  -v "$PWD":/work -w /work \
  ghcr.io/gregolsky/pebble-sdk:latest \
  bash -c "pebble build && pebble install --emulator basalt"
```

### Headless screenshot

```bash
docker run --rm \
  -e SDL_VIDEODRIVER=dummy \
  -e SDL_AUDIODRIVER=dummy \
  -v "$PWD":/work -w /work \
  ghcr.io/gregolsky/pebble-sdk:latest \
  bash -c "pebble build && pebble install --emulator basalt && pebble screenshot --emulator basalt /work/screenshot.png"
```

### GitHub Actions CI

```yaml
jobs:
  build:
    runs-on: ubuntu-latest
    container:
      image: ghcr.io/gregolsky/pebble-sdk:latest
    steps:
      - uses: actions/checkout@v4
      - run: pebble build
      - uses: actions/upload-artifact@v4
        with:
          name: watchapp
          path: build/*.pbw
```

### Pin to exact versions (reproducible CI)

```yaml
container:
  image: ghcr.io/gregolsky/pebble-sdk:pebble-tool-5.0.37-sdk-4.9.169
```

## Versioning Policy

A new image release is cut whenever `scripts/resolve-upstream-versions.sh` (run weekly via cron) detects that **either**:
- A new `pebble-tool` version is published to PyPI (`https://pypi.org/pypi/pebble-tool/json`), **or**
- `pebble sdk install latest` would resolve to a newer SDK version than the one in the current release.

The cron workflow opens a pull request that bumps `versions.env`. Merging that PR triggers the release workflow which builds multi-arch and pushes all tags.

**Retention:** The last 10 versioned tag pairs (`pebble-tool-X-sdk-Y`) are kept on both registries. Older images are pruned automatically via GitHub Actions at release time.

**`latest` semantics:** Points to the most recently published release. Never mutated for a past release.

## Environment Variables

| Variable | Default in image | Purpose |
|---|---|---|
| `PEBBLE_TOOL_VERSION` | Set at build time | pebble-tool version baked in |
| `PEBBLE_SDK_VERSION` | Set at build time | SDK version baked in |
| `SDL_VIDEODRIVER` | `dummy` | Headless SDL; set to unset for X11 |
| `SDL_AUDIODRIVER` | `dummy` | Silence audio output |
| `PEBBLE_HOME` | `/home/pebble/.pebble-sdk` | SDK home, analytics opt-out configured here |
| `UV_TOOL_DIR` | `/opt/uv-tools` | Where `uv tool install` lands |

## Image Labels

OCI standard labels:

| Label | Value |
|---|---|
| `org.opencontainers.image.source` | `https://github.com/gregolsky/docker-pebble-sdk` |
| `org.opencontainers.image.version` | git tag of the build |
| `org.opencontainers.image.revision` | git SHA |
| `org.opencontainers.image.created` | ISO 8601 build timestamp |
| `org.opencontainers.image.description` | Short description |
| `org.opencontainers.image.licenses` | Apache-2.0 |

Custom labels:

| Label | Value |
|---|---|
| `io.pebble.tool.version` | Exact pebble-tool PyPI version |
| `io.pebble.sdk.version` | Exact SDK version installed |

## Filesystem Layout Inside Image

```
/opt/uv-tools/pebble-tool/     ← uv tool install dir (UV_TOOL_DIR)
  bin/pebble                   ← pebble-tool binary on PATH
  lib/python3.13/...           ← pebble-tool + libpebble2 venv

/home/pebble/.local/share/pebble-sdk/
  SDKs/<ver>/                  ← Pebble SDK headers, resources, firmware
  current -> SDKs/<ver>        ← symlink to active SDK
  SDKs/<ver>/arm-cs-tools/     ← arm-none-eabi cross-toolchain

/work/                         ← default WORKDIR; mount your project here
```

## Non-Root User

The image runs as user `pebble` (uid 1000). The `/work` directory is owned by `pebble`. If your host project files are owned by a different uid, either:

- Use `--user $(id -u):$(id -g)` and mount a pre-chowned volume, or
- Set `HOME` to a writable directory via `-e HOME=/tmp`.

The `pebble` user has no `sudo` access inside the image.

## Dockerfile Architecture (Multi-Stage)

**Stage 1 — `base`**: `debian:bookworm-slim` + apt packages (Node LTS, gcc, make, libc-dev, libsdl2-2.0-0, imagemagick, curl, ca-certificates).

**Stage 2 — `pebble-install`**: Install `uv`, create user `pebble`, run `uv tool install pebble-tool --python 3.13` as `pebble`, verify `pebble --version`.

**Stage 3 — `sdk-install`**: As user `pebble`, run `pebble sdk install latest` which downloads the ARM toolchain and SDK. Strip apt/uv caches.

**Final stage**: Copies from `sdk-install`, sets `ENV` vars, exposes `WORKDIR /work`, sets `ENTRYPOINT scripts/entrypoint.sh`, sets `CMD ["pebble", "build"]`.

The ARM toolchain download is the longest step (~300 MB). It is in its own layer so it is cache-friendly across pebble-tool-only bumps.

## CI/CD Workflows

### `build.yml` — PR / push to main

Trigger: `push` to `main`, `pull_request` to `main`.

Steps:
1. `docker/setup-buildx-action`
2. `docker buildx build --platform linux/amd64,linux/arm64 --load` (no push)
3. `bash test/smoke.sh` — builds the smoke watchapp inside the image for each platform

### `release.yml` — tag push

Trigger: `push` of tag matching `v*`.

Steps:
1. `docker/login-action` for GHCR (`ghcr.io`, token: `GITHUB_TOKEN`)
2. `docker/login-action` for Docker Hub (secrets: `DOCKERHUB_USERNAME`, `DOCKERHUB_TOKEN`)
3. `docker/metadata-action` generates all tags from the tag + `versions.env`
4. `docker/build-push-action` with `--platform linux/amd64,linux/arm64`, `--push`, `--provenance`, `--sbom`
5. GitHub Release created via `gh release create` with SBOM attached
6. Prune old tags: keep last 10 versioned pairs per registry

### `weekly-check.yml` — upstream version cron

Trigger: `schedule: '0 6 * * 1'` (Mondays 06:00 UTC) + `workflow_dispatch`.

Steps:
1. Run `scripts/resolve-upstream-versions.sh` → outputs `LATEST_TOOL_VER` and `LATEST_SDK_VER`
2. Compare against `versions.env` in `main`
3. If either differs: create a branch `bump/pebble-tool-X.Y.Z-sdk-A.B.C`, update `versions.env`, open a pull request (title: `chore: bump pebble-tool X.Y.Z / SDK A.B.C`)
4. If identical: no-op, log "versions already current"

Merging the PR triggers `build.yml`; tagging the merge commit triggers `release.yml`.

## Secrets Required

| Secret | Where | Purpose |
|---|---|---|
| `DOCKERHUB_USERNAME` | Repository secrets | Docker Hub login |
| `DOCKERHUB_TOKEN` | Repository secrets | Docker Hub push token |
| `GITHUB_TOKEN` | Automatic | GHCR push + PR creation |

No other secrets. The version-check cron uses only anonymous public APIs (PyPI JSON, GitHub Releases API).

## Smoke Test

`test/smoke/` is a minimal valid Pebble watchapp (a single `src/c/main.c` with an empty window). `test/smoke.sh` runs:

```bash
docker run --rm \
  -v "$(pwd)/test/smoke":/work -w /work \
  "${IMAGE:-pebble-sdk:test}" \
  pebble build

test -f test/smoke/build/smoke.pbw || { echo "FAIL: .pbw not produced"; exit 1; }
echo "PASS"
```

The smoke test runs on every PR and both architectures. It validates the entire toolchain: uv → pebble-tool → ARM cross-compiler → linker → `.pbw` output.

## Known Limitations

- **diorite / emery emulators**: Upstream-broken in current `pebble-tool` (regression noted in `fast-wasp-pebble`). Builds targeting those platforms work; emulator-based install/screenshot does not.
- **X11 / interactive GUI emulator**: Not supported. `SDL_VIDEODRIVER=dummy` is the only supported mode.
- **Bluetooth / phone pairing**: `pebble install --phone <ip>` requires host network access and a phone on the same LAN; container networking makes this impractical.
- **Analytics**: `pebble-tool` phone-home analytics are disabled via `PEBBLE_HOME` opt-out in the image.

## License

This repository is Apache 2.0 licensed. The Pebble SDK and `pebble-tool` are subject to their own licenses; see [developer.repebble.com](https://developer.repebble.com) and the [coredevices/pebble-tool](https://github.com/coredevices/pebble-tool) repository.

## References

- Official install docs: https://developer.repebble.com/sdk/
- Active SDK tool: https://github.com/coredevices/pebble-tool
- pebble-tool on PyPI: https://pypi.org/project/pebble-tool/
- Rebble community: https://rebble.io
- Abandoned prior Docker image: https://hub.docker.com/r/rebble/pebble-sdk (last updated 2019)
- Dormant Docker repo: https://github.com/pebble-dev/rebble-docker
- Community 2025 install guide: https://www.richinfante.com/2025/02/09/building-pebble-watchfaces-on-modern-systems-sdk
