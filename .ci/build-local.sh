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
OUTDIR="$WORKDIR/output/$ARCH"
KEYSDIR="$WORKDIR/keys"
mkdir -p "$OUTDIR" "$KEYSDIR"

echo "Building packages ($PKGS) for $ARCH via $PLATFORM"

docker run --rm --platform "$PLATFORM" \
  -e ABUILD_PRIVKEY \
  -e ARCH="$ARCH" \
  -e PKGS="$PKGS" \
  -v "$WORKDIR":/workspace \
  -w /workspace \
  alpine:latest \
  sh -exc '
    set -e
    apk add --no-cache alpine-sdk doas sudo bash findutils coreutils

    adduser -D builder || true
    addgroup builder abuild || true
    adduser builder abuild || true

    mkdir -p /etc/doas.d
    printf "permit nopass :abuild\npermit nopass root as builder\npermit nopass builder\n" > /etc/doas.d/abuild.conf

    # Create build script
    cat > /workspace/build-packages.sh << SCRIPT_EOF
#!/bin/sh
set -ex
cd ~
mkdir -p ~/.abuild
if [ -n "\${ABUILD_PRIVKEY:-}" ]; then
  printf "%s" "\${ABUILD_PRIVKEY}" > ~/.abuild/privkey.rsa
  chmod 600 ~/.abuild/privkey.rsa
  KEY=~/.abuild/privkey.rsa
else
  # Generate new keypair
  abuild-keygen -n -a || true
  KEY=\$(ls ~/.abuild/builder-*.rsa)
fi
echo "PACKAGER=\"Local Builder\"" > ~/.abuild/abuild.conf
echo "PACKAGER_PRIVKEY=\$KEY" >> ~/.abuild/abuild.conf

# Install the public key for signing
doas cp \$(ls ~/.abuild/*.pub) /etc/apk/keys/

for pkg in $PKGS; do
  echo "=== Building \$pkg ==="
  cd /workspace/main/\$pkg || exit 1
  echo "Current directory: \$(pwd)"
  ls -la
  echo "Running abuild -r..."
  set +e  # Temporarily disable exit on error
  abuild -r
  RESULT=$?
  set -e  # Re-enable exit on error
  
  # Check if APK was created despite potential index errors
  if find ~/packages -name "\$pkg-*.apk" | grep -q "."; then
    echo "Build completed for \$pkg (APK successfully created)"
  elif [ $RESULT -eq 0 ]; then
    echo "Build successful for \$pkg"  
  else
    echo "Build failed for \$pkg (exit code: $RESULT)"
    exit 1
  fi
  echo "Checking for generated packages:"
  find ~/packages -name "*.apk" -ls 2>/dev/null || echo "No APKs found for \$pkg yet"
done
SCRIPT_EOF

    chmod +x /workspace/build-packages.sh
    su - builder -s /bin/sh -c '/workspace/build-packages.sh'    # Export artifacts
    echo "=== Searching for APKs ==="
    find /home/builder/packages -type f -name "*.apk" -ls 2>/dev/null || echo "No APKs found"
    echo "=== Copying APKs ==="
    cp /home/builder/.abuild/*.pub /workspace/keys/alpine.pub || true
    find /home/builder/packages -type f \
      \( -path "*/${ARCH}/*" -o -path "*/noarch/*" \) \
      -name "*.apk" -exec cp {} /workspace/output/${ARCH}/ \; 2>/dev/null || true
    echo "=== Final check ==="
    ls -la /workspace/output/${ARCH}/ || true
  '

echo "Done. Artifacts in $OUTDIR"
