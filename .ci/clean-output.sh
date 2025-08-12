#!/usr/bin/env bash
set -euo pipefail

# Hard clean of generated repository content.
# Removes output/* and keys/alpine.pub (but keeps keys directory).

ROOT=$(cd "$(dirname "$0")/.." && pwd)
echo "[clean] Removing output repository content"
rm -rf "$ROOT/output" || true
mkdir -p "$ROOT/output"
if [ -f "$ROOT/keys/alpine.pub" ]; then
  rm -f "$ROOT/keys/alpine.pub"
  echo "[clean] Removed keys/alpine.pub"
fi
echo "[clean] Done."
