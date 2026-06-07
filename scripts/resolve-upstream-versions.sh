#!/usr/bin/env bash
# Queries PyPI and the Pebble SDK manifest for the latest published versions.
# Outputs two lines suitable for sourcing:
#   LATEST_TOOL_VER=x.y.z
#   LATEST_SDK_VER=a.b.c
set -euo pipefail

LATEST_TOOL_VER=$(curl -fsSL "https://pypi.org/pypi/pebble-tool/json" \
    | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['info']['version'])")

# The Pebble SDK manifest endpoint used by pebble-tool itself
SDK_MANIFEST_URL="https://developer.rebble.io/sdk/update-check.json"
LATEST_SDK_VER=$(curl -fsSL "${SDK_MANIFEST_URL}" \
    | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['sdkVersion'])" 2>/dev/null \
    || echo "unknown")

echo "LATEST_TOOL_VER=${LATEST_TOOL_VER}"
echo "LATEST_SDK_VER=${LATEST_SDK_VER}"
