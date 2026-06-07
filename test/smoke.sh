#!/usr/bin/env bash
# Smoke test: build the minimal watchapp inside the image and assert a .pbw is produced.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
IMAGE="${IMAGE:-pebble-sdk:test}"

echo "==> Smoke test: pebble build using image ${IMAGE}"

# Mount source read-only at /src; copy into /work (owned by the pebble user inside
# the image) and build there. Avoids host-uid mismatch when runner uid != pebble uid.
docker run --rm \
    -v "${REPO_ROOT}/test/smoke":/src:ro \
    "${IMAGE}" \
    bash -c '
        set -e
        cp -r /src/. /work/
        cd /work
        pebble build
        test -f build/smoke.pbw
        echo "PASS: smoke.pbw produced ($(du -h build/smoke.pbw | cut -f1))"
    '
