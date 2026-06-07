#!/usr/bin/env bash
# Queries PyPI and the Pebble SDK manifest for the latest published versions.
# Outputs two lines suitable for sourcing:
#   LATEST_TOOL_VER=x.y.z
#   LATEST_SDK_VER=a.b.c
set -euo pipefail

LATEST_TOOL_VER=$(curl -fsSL "https://pypi.org/pypi/pebble-tool/json" \
    | python3 -c "import sys,json; print(json.load(sys.stdin)['info']['version'])")

# Core Devices' Re:Pebble SDK manifest (same endpoint pebble-tool itself queries)
LATEST_SDK_VER=$(curl -fsSL "https://sdk.repebble.com/v1/files/sdk-core?channel=release" \
    | python3 -c "import sys,json; print(json.load(sys.stdin)['files'][-1]['version'])")

echo "LATEST_TOOL_VER=${LATEST_TOOL_VER}"
echo "LATEST_SDK_VER=${LATEST_SDK_VER}"
