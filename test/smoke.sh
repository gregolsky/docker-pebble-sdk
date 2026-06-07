#!/usr/bin/env bash
# Smoke test: build the minimal watchapp inside the image and assert a .pbw is produced.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
IMAGE="${IMAGE:-pebble-sdk:test}"

echo "==> Smoke test: pebble build using image ${IMAGE}"

# Clean previous build artifacts
rm -rf "${REPO_ROOT}/test/smoke/build"

docker run --rm \
    -v "${REPO_ROOT}/test/smoke":/work \
    -w /work \
    "${IMAGE}" \
    pebble build

if [ ! -f "${REPO_ROOT}/test/smoke/build/smoke.pbw" ]; then
    echo "FAIL: smoke.pbw not found after pebble build"
    exit 1
fi

echo "PASS: smoke.pbw produced ($(du -h "${REPO_ROOT}/test/smoke/build/smoke.pbw" | cut -f1))"
