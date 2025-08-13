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
  printf "%s" "${ABUILD_PRIVKEY}" > ~/.abuild/alpine.rsa
  chmod 600 ~/.abuild/alpine.rsa
  KEY=~/.abuild/alpine.rsa
  if [ -n "${ABUILD_PUBKEY:-}" ]; then
    printf "%s" "${ABUILD_PUBKEY}" > ~/.abuild/alpine.rsa.pub
  elif [ ! -f ~/.abuild/alpine.rsa.pub ] && command -v openssl >/dev/null 2>&1; then
    # Derive public key if not supplied
    openssl rsa -in "$KEY" -pubout > ~/.abuild/alpine.rsa.pub 2>/dev/null || true
  fi
  echo "PACKAGER=\"Automated Builder\"" > ~/.abuild/abuild.conf
  echo "PACKAGER_PRIVKEY=$KEY" >> ~/.abuild/abuild.conf
  if [ -f ~/.abuild/alpine.rsa.pub ]; then
    install -m 644 ~/.abuild/alpine.rsa.pub /etc/apk/keys/alpine.rsa.pub 2>/dev/null || true
    echo "[builder] Installed CI public key as alpine.rsa.pub"
  else
    echo "[warn] Public key not present after setup (CI path)" >&2
  fi
else
  # Local mode: require an existing key pair under /workspace/keys
  if [ -f /workspace/keys/alpine.rsa ]; then
    echo "Reusing existing local key /workspace/keys/alpine.rsa"
    cp /workspace/keys/alpine.rsa ~/.abuild/alpine.rsa
    chmod 600 ~/.abuild/alpine.rsa
    KEY=~/.abuild/alpine.rsa
    if [ -f /workspace/keys/alpine.rsa.pub ]; then
      cp /workspace/keys/alpine.rsa.pub ~/.abuild/alpine.rsa.pub
    elif [ -f /workspace/keys/alpine.pub ]; then
      cp /workspace/keys/alpine.pub ~/.abuild/alpine.rsa.pub
      cp /workspace/keys/alpine.pub /workspace/keys/alpine.rsa.pub 2>/dev/null || true
    elif command -v openssl >/dev/null 2>&1; then
      openssl rsa -in "$KEY" -pubout > ~/.abuild/alpine.rsa.pub 2>/dev/null || true
      cp ~/.abuild/alpine.rsa.pub /workspace/keys/alpine.rsa.pub 2>/dev/null || true
    fi
    if [ -f ~/.abuild/alpine.rsa.pub ]; then
      install -m 644 ~/.abuild/alpine.rsa.pub /etc/apk/keys/alpine.rsa.pub 2>/dev/null || true
      echo "[builder] Installed local public key as alpine.rsa.pub"
    else
      echo "[error] Could not obtain public key for local private key." >&2
      exit 1
    fi
    echo "PACKAGER=\"Local Builder\"" > ~/.abuild/abuild.conf
    echo "PACKAGER_PRIVKEY=$KEY" >> ~/.abuild/abuild.conf
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
echo "[builder] Key debug: private key size: $(wc -c < ~/.abuild/alpine.rsa 2>/dev/null || echo 0) bytes; public key present? $( [ -f ~/.abuild/alpine.rsa.pub ] && echo yes || echo no )"

# Ensure our public key is installed in keyring with proper name
if [ -f ~/.abuild/alpine.rsa.pub ]; then
  doas cp ~/.abuild/alpine.rsa.pub /etc/apk/keys/alpine.rsa.pub
  doas chmod 644 /etc/apk/keys/alpine.rsa.pub
  echo "[builder] Forcibly installed public key as /etc/apk/keys/alpine.rsa.pub"
fi

ls -l /etc/apk/keys | sed 's/^/[builder] keyring /'
echo "[builder] Our public key content (first 3 lines):"
head -n3 ~/.abuild/alpine.rsa.pub 2>/dev/null | sed 's/^/[builder] /' || echo "[builder] No public key found"
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
  # Don't force re-sign APKs - let abuild handle signing with our configured key
  echo "[builder] APKs will be signed by abuild using PACKAGER_PRIVKEY=$KEY"
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
  echo "[builder] Verifying built APK signatures before indexing"
  for a in *.apk; do
    echo "[verify] Checking $a - signature entries: $(tar -tf "$a" | grep -c '^\.SIGN' || echo 0)"
    if ! apk verify "$a" >/dev/null 2>&1; then
      echo "[verify] UNTRUSTED: $a" >&2
      echo "[debug] Listing signature entries inside APK:" >&2
      tar -tf "$a" | grep -E '^\.SIGN' || true
      echo "[debug] Current keyring contents:" >&2
      ls -la /etc/apk/keys | grep -v '^total' >&2 || true
      echo "[debug] Public key used (first lines):" >&2
      head -n5 ~/.abuild/alpine.rsa.pub 2>/dev/null >&2 || true
      echo "[debug] Testing manual apk verify with verbose output:" >&2
      apk verify --verbose "$a" 2>&1 >&2 || true
      exit 99
    fi
    echo "[verify] OK: $a"
  done
  echo "[builder] Creating APKINDEX (abuild already signed with our key)"
  if ! apk index -o APKINDEX.tar.gz *.apk; then
    echo "[builder] Regular index failed, trying with --allow-untrusted"
    apk index --allow-untrusted -o APKINDEX.tar.gz *.apk || { echo "Index creation failed" >&2; exit 1; }
  fi
  # No need to re-sign APKINDEX - abuild already did it with our key during build
  echo "[builder] APKINDEX created (using existing signature from abuild)"
else
  echo "[builder] No APKs to index"
fi
BUILDER_EOF

chmod +x /tmp/run-as-builder.sh
chown -R builder:builder /workspace "$OUTPUT_DIR"

su - builder -s /bin/sh -c "ABUILD_PRIVKEY='${ABUILD_PRIVKEY:-}' ARCH='${ARCH}' PKGS='${PKGS}' OUTPUT_DIR='${OUTPUT_DIR}' /tmp/run-as-builder.sh"

# Sync canonical public key back
cp /home/builder/.abuild/alpine.rsa.pub /workspace/keys/alpine.rsa.pub 2>/dev/null || true
echo "[common] Final contents of $OUTPUT_DIR:"; ls -la "$OUTPUT_DIR"
echo "[common] Done"
