# docker-pebble-sdk

Maintained Docker image for Pebble smartwatch development.

Installs [`pebble-tool`](https://github.com/coredevices/pebble-tool) via `uv` (the official install path per [developer.repebble.com](https://developer.repebble.com/sdk/)) and bakes in the latest Pebble SDK. Multi-arch: `linux/amd64` + `linux/arm64`. Rebuilt automatically each week when either `pebble-tool` or the SDK releases a new version.

See [SPECS.md](SPECS.md) for the full specification.

## Quick start

```bash
# Build a .pbw
docker run --rm -v "$PWD":/work -w /work \
  ghcr.io/gregolsky/pebble-sdk:latest pebble build

# Headless emulator
docker run --rm \
  -e SDL_VIDEODRIVER=dummy -e SDL_AUDIODRIVER=dummy \
  -v "$PWD":/work -w /work \
  ghcr.io/gregolsky/pebble-sdk:latest \
  bash -c "pebble build && pebble install --emulator basalt"
```

## Current versions

| Component | Version |
|---|---|
| pebble-tool | 5.0.37 |
| Pebble SDK | 4.9.169 |
| Python | 3.13 |
| Node.js | LTS |

## GitHub Actions

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

## Registries

- `ghcr.io/gregolsky/pebble-sdk`
- `docker.io/gregolsky/pebble-sdk`

## License

MIT — see [LICENSE](LICENSE). The Pebble SDK and pebble-tool are subject to their own licenses; see [coredevices/pebble-tool](https://github.com/coredevices/pebble-tool).
