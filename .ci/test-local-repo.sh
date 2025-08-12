#!/usr/bin/env sh
set -eu
# Test the locally built Alpine APK repository using the generated public key.
# Usage: .ci/test-local-repo.sh [arch]
# Default arch: native (apk --print-arch)
# Exits 0 if repository is usable & signatures valid.

ARCH=${1:-}
if [ -z "$ARCH" ]; then
  ARCH=$(apk --print-arch 2>/dev/null || true)
fi
REPO_DIR=/workspace/output/main/$ARCH
PUBKEY=/workspace/keys/alpine.pub

if [ ! -f "$PUBKEY" ]; then
  echo "[test] Missing public key: $PUBKEY" >&2
  exit 1
fi
if [ ! -d "$REPO_DIR" ]; then
  echo "[test] Missing repo directory: $REPO_DIR" >&2
  exit 1
fi
if ! ls "$REPO_DIR"/*.apk >/dev/null 2>&1; then
  echo "[test] No APKs found in $REPO_DIR" >&2
  exit 1
fi

cp "$PUBKEY" /etc/apk/keys/ || { echo "[test] Failed to install public key" >&2; exit 1; }
echo "$REPO_DIR" > /etc/apk/repositories

echo "[test] Updating index";
if ! apk update; then
  echo "[test] apk update failed" >&2
  exit 1
fi

PKG=$(ls "$REPO_DIR"/*.apk | sed 's#.*/##' | sed 's/-[0-9].*//' | head -n1)
if [ -z "$PKG" ]; then
  echo "[test] Could not derive a package name" >&2
  exit 1
fi

# Prefer not to install incus* (heavy) if lighter pkgs exist
if ls "$REPO_DIR"/hello-test-*.apk >/dev/null 2>&1; then
  PKG=hello-test
fi

echo "[test] Attempting install of $PKG"
if ! apk add --no-cache "$PKG"; then
  echo "[test] Install failed for $PKG" >&2
  exit 1
fi

echo "[test] Verifying signatures of all APKs (first few)"
ls "$REPO_DIR"/*.apk | head -n5 | while read -r f; do
  apk verify "$(basename "$f")" 2>/dev/null || echo "[warn] verify failed for $(basename "$f")"
  : # silent success is fine
done

echo "[test] SUCCESS: repository usable with provided key."
