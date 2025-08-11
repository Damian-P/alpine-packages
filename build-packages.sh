#!/bin/sh
set -ex
cd ~
mkdir -p ~/.abuild
if [ -n "${ABUILD_PRIVKEY:-}" ]; then
  printf "%s" "${ABUILD_PRIVKEY}" > ~/.abuild/privkey.rsa
  chmod 600 ~/.abuild/privkey.rsa
  KEY=~/.abuild/privkey.rsa
else
  # Generate new keypair
  abuild-keygen -n -a || true
  KEY=$(ls ~/.abuild/builder-*.rsa)
fi
echo "PACKAGER=\"Local Builder\"" > ~/.abuild/abuild.conf
echo "PACKAGER_PRIVKEY=$KEY" >> ~/.abuild/abuild.conf

# Install the public key for signing
doas cp $(ls ~/.abuild/*.pub) /etc/apk/keys/

for pkg in hello-test; do
  echo "=== Building $pkg ==="
  cd /workspace/main/$pkg || exit 1
  echo "Current directory: $(pwd)"
  ls -la
  echo "Running abuild -r..."
  set +e  # Temporarily disable exit on error
  abuild -r
  RESULT=0
  set -e  # Re-enable exit on error
  
  # Check if APK was created despite potential index errors
  if find ~/packages -name "$pkg-*.apk" | grep -q "."; then
    echo "Build completed for $pkg (APK successfully created)"
  elif [  -eq 0 ]; then
    echo "Build successful for $pkg"  
  else
    echo "Build failed for $pkg (exit code: )"
    exit 1
  fi
  echo "Checking for generated packages:"
  find ~/packages -name "*.apk" -ls 2>/dev/null || echo "No APKs found for $pkg yet"
done
