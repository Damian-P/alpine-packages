#!/usr/bin/env bash
set -euo pipefail

# Simple local builder using Docker for Alpine APKs (x86_64 and aarch64)
# Usage:
#   ./.ci/build-local.sh [x86_64|aarch64] [pkg1 pkg2 ...]
# Examples:
#   ./.ci/build-local.sh x86_64 hello-test
#   ./.ci/build-local.sh aarch64 hello-test

ARCH=${1:-x86_64}
shift || true
PKGS=${*:-hello-test}

if [[ "$ARCH" == "aarch64" ]]; then
  PLATFORM=linux/arm64
else
  PLATFORM=linux/amd64
fi

WORKDIR=$(cd "$(dirname "$0")/.." && pwd)
OUTDIR="$WORKDIR/output"
KEYSDIR="$WORKDIR/keys"
mkdir -p "$OUTDIR" "$KEYSDIR"

echo "Building packages ($PKGS) for $ARCH via $PLATFORM"
echo "Reusing any existing packages in $OUTDIR (cumulative index)"

docker run --rm --platform "$PLATFORM" \
  -e ABUILD_PRIVKEY \
  -e ARCH="$ARCH" \
  -e PKGS="$PKGS" \
  -e OUTPUT_DIR="/workspace/output" \
  -v "$WORKDIR":/workspace \
  -w /workspace \
  alpine:latest \
  sh .ci/build-common-inside-container.sh

echo "Done. Cumulative artifacts in $OUTDIR"
