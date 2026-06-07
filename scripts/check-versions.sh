#!/usr/bin/env bash
# Prints the pebble-tool and SDK versions baked into this image.
set -euo pipefail

TOOL_VER=$(pebble --version 2>&1 | grep -oP '\d+\.\d+\.\d+' | head -1)
SDK_VER=$(pebble sdk list 2>/dev/null | grep -oP '\d+\.\d+\.\d+' | sort -V | tail -1)

echo "pebble-tool: ${TOOL_VER}"
echo "sdk:         ${SDK_VER}"
