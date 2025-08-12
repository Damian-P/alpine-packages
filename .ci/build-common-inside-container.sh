#!/bin/sh
set -eu

# Common build logic executed inside the Alpine container.
# Env:
#   ARCH           Target arch (x86_64, aarch64, ...)
#   PKGS           Space separated list of package dirs under main/
#   ABUILD_PRIVKEY Optional private key content (RSA key)
#   OUTPUT_DIR     Final repository dir (default /workspace/output/main/$ARCH)

ARCH=${ARCH:-x86_64}
PKGS=${PKGS:-}
OUTPUT_DIR=${OUTPUT_DIR:-/workspace/output/main/$ARCH}

echo "[common] ARCH=$ARCH"
echo "[common] PKGS=$PKGS"
echo "[common] OUTPUT_DIR=$OUTPUT_DIR"

mkdir -p "$OUTPUT_DIR" /workspace/keys

apk update
apk add --no-cache alpine-sdk doas sudo bash findutils coreutils tar
echo "Adding user and group for building"
adduser -D builder 2>/dev/null || true
echo "Adding builder to abuild group"
addgroup builder abuild 2>/dev/null || true
echo "Adding builder to abuild group"
adduser builder abuild 2>/dev/null || true

mkdir -p /etc/doas.d

cat > /etc/doas.d/abuild.conf << EOF
permit nopass :abuild
permit nopass root as builder
permit nopass builder
EOF

cat > /tmp/run-as-builder.sh <<'BUILDER_EOF'
#!/bin/sh
set -eu
echo "Running as builder"
mkdir -p ~/.abuild
if [ -n "${ABUILD_PRIVKEY:-}" ]; then
  # Private key supplied via environment (CI case)
  printf "%s" "${ABUILD_PRIVKEY}" > ~/.abuild/privkey.rsa
  chmod 600 ~/.abuild/privkey.rsa
  KEY=~/.abuild/privkey.rsa
  if [ -n "${ABUILD_PUBKEY:-}" ]; then
    printf "%s" "${ABUILD_PUBKEY}" > ~/.abuild/privkey.rsa.pub
  elif command -v openssl >/dev/null 2>&1; then
    openssl rsa -in "$KEY" -pubout > ~/.abuild/privkey.rsa.pub 2>/dev/null || true
  fi
  echo "PACKAGER=\"Automated Builder\"" > ~/.abuild/abuild.conf
  echo "PACKAGER_PRIVKEY=$KEY" >> ~/.abuild/abuild.conf
  cp ~/.abuild/*.pub /etc/apk/keys/ 2>/dev/null || true
else
  # Local mode: require an existing key pair under /workspace/keys
  if [ -f /workspace/keys/alpine.rsa ]; then
    echo "Reusing existing local key /workspace/keys/alpine.rsa"
    cp /workspace/keys/alpine.rsa ~/.abuild/privkey.rsa
    chmod 600 ~/.abuild/privkey.rsa
    KEY=~/.abuild/privkey.rsa
    if [ -f /workspace/keys/alpine.pub ]; then
      cp /workspace/keys/alpine.pub ~/.abuild/privkey.rsa.pub || true
    elif command -v openssl >/dev/null 2>&1; then
      openssl rsa -in "$KEY" -pubout > ~/.abuild/privkey.rsa.pub 2>/dev/null || true
    fi
    cp /workspace/keys/alpine.pub /etc/apk/keys/ 2>/dev/null || true
  else
    echo "[error] No ABUILD_PRIVKEY provided and no /workspace/keys/alpine.rsa found."
    echo "        Generate a key pair first (example):"
    echo "        docker run --rm -v \"$PWD\":/w -w /w alpine:latest sh -c 'apk add --no-cache alpine-sdk && abuild-keygen -n -a && cp /root/.abuild/*.rsa keys/alpine.rsa && cp /root/.abuild/*.pub keys/alpine.pub'"
    exit 1
  fi
fi

if [ -z "${ARCH:-}" ]; then
  # Fallback: detect first arch directory in abuild output
  ARCH=$(find ~/packages -maxdepth 1 -type d -printf '%f\n' 2>/dev/null | grep -E '^(x86_64|aarch64|armhf|armv7|ppc64le|s390x)$' | head -n1 || true)
fi
echo "[builder] Using ARCH=$ARCH"
echo "[builder] Building packages: $PKGS"
for pkg in $PKGS; do
  [ -z "$pkg" ] && continue
  echo "[builder] === $pkg ==="
  cd /workspace/main/$pkg || { echo "Missing main/$pkg" >&2; exit 1; }
  abuild checksum
  if ! abuild -r; then
    if ! ls ~/packages/*/*/${pkg}-*.apk 2>/dev/null | grep -q .; then
      echo "[builder] Build failed for $pkg" >&2
      exit 1
    fi
  fi
done

echo "[builder] Collecting APKs into $OUTPUT_DIR (cumulative)"
mkdir -p "$OUTPUT_DIR"
# Copy freshly built APKs (only arch-specific + noarch)
if [ -n "${ARCH:-}" ]; then
  find ~/packages -type f \( -path "*/$ARCH/*.apk" -o -path "*/noarch/*.apk" \) -exec cp -u {} "$OUTPUT_DIR"/ \; 2>/dev/null || true
else
  echo "[builder] ARCH not set; copying any APKs found (best-effort)"
  find ~/packages -type f -name '*.apk' -exec cp -u {} "$OUTPUT_DIR"/ \; 2>/dev/null || true
fi

cd "$OUTPUT_DIR"
if [ "${PRUNE_OLD:-0}" = "1" ]; then
  PRUNE_KEEP=${PRUNE_KEEP:-1}
  echo "[builder] Pruning older versions (keeping $PRUNE_KEEP per package)"
  basenames=$(ls *.apk 2>/dev/null | sed -n 's/\(.*\)-[0-9][^-]*-r[0-9][0-9]*\.apk$/\1/p' | sort -u || true)
  for base in $basenames; do
    files=$(ls ${base}-*-r*.apk 2>/dev/null | sort -V || true)
    # Keep last N (PRUNE_KEEP) entries
    keep=$(echo "$files" | tail -n "$PRUNE_KEEP")
    for f in $files; do
      echo "$keep" | grep -qx "$f" && continue
      echo "[prune] removing $f"
      rm -f -- "$f" || true
    done
  done
fi

echo "[builder] Regenerating APKINDEX ("$(ls -1 *.apk 2>/dev/null | wc -l)" APKs)"
rm -f APKINDEX.tar.gz APKINDEX.tar.gz.sig || true
if ls *.apk >/dev/null 2>&1; then
  apk index -o APKINDEX.tar.gz *.apk
  abuild-sign -k "$KEY" APKINDEX.tar.gz || { echo "Signing failed" >&2; exit 1; }
else
  echo "[builder] No APKs to index"
fi
BUILDER_EOF

chmod +x /tmp/run-as-builder.sh
chown -R builder:builder /workspace "$OUTPUT_DIR"

su - builder -s /bin/sh -c "ABUILD_PRIVKEY='${ABUILD_PRIVKEY:-}' ARCH='${ARCH}' PKGS='${PKGS}' OUTPUT_DIR='${OUTPUT_DIR}' /tmp/run-as-builder.sh"

# Always refresh exported public key (harmless overwrite)
cp /home/builder/.abuild/*.pub /workspace/keys/alpine.pub 2>/dev/null || true
echo "[common] Final contents of $OUTPUT_DIR:"; ls -la "$OUTPUT_DIR"
echo "[common] Done"
