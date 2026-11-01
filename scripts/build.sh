#!/usr/bin/env bash
# Switch FFmpeg only; preserves the Firebase mode. Does not resolve or build.
# Usage: scripts/build.sh <with|without|check>
set -euo pipefail
cd "$(dirname "$0")/.."
if command -v python >/dev/null 2>&1; then
  exec python scripts/configure_build.py ffmpeg "${1:-}"
else
  exec python3 scripts/configure_build.py ffmpeg "${1:-}"
fi
