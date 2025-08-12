#!/bin/sh
set -eu

# Common build logic executed inside the Alpine container.
# Env:
#   ARCH           Target arch (x86_64, aarch64, ...)
#   PKGS           Space separated list of package dirs under main/
#   ABUILD_PRIVKEY Optional private key content (RSA key)
#   OUTPUT_DIR     Repo output dir (default /workspace/output/$ARCH)

ARCH=${ARCH:-x86_64}
PKGS=${PKGS:-}
OUTPUT_DIR=${OUTPUT_DIR:-/workspace/output}

echo "[common] ARCH=$ARCH"
echo "[common] PKGS=$PKGS"
echo "[common] OUTPUT_DIR=$OUTPUT_DIR"

mkdir -p "$OUTPUT_DIR" /workspace/keys

apk update
apk add --no-cache alpine-sdk doas sudo bash findutils coreutils tar
echo "Adding user and group for building"
adduser -D builder
echo "Adding builder to abuild group"
addgroup builder abuild
echo "Adding builder to abuild group"
adduser builder abuild

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
  printf "%s" "${ABUILD_PRIVKEY}" > ~/.abuild/privkey.rsa
  chmod 600 ~/.abuild/privkey.rsa
  KEY=~/.abuild/privkey.rsa
  echo "PACKAGER=\"Automated Builder\"" > ~/.abuild/abuild.conf
  echo "PACKAGER_PRIVKEY=$KEY" >> ~/.abuild/abuild.conf
  cp ~/.abuild/*.pub /etc/apk/keys/ 2>/dev/null
else
  echo "Generating new RSA key for abuild"
  abuild-keygen -n -a -i
  KEY=$(ls ~/.abuild/*.rsa 2>/dev/null | head -n1)
fi

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

echo "[builder] Copying built packages to $OUTPUT_DIR"
cp -r ~/packages/* "$OUTPUT_DIR"

# echo "[builder] Collecting APKs into $OUTPUT_DIR"
# find ~/packages -type f -name '*.apk' -exec cp -u {} "$OUTPUT_DIR" \; 2>/dev/null

# cd "$OUTPUT_DIR"
# echo "[builder] Regenerating APKINDEX ("$(ls -1 *.apk 2>/dev/null | wc -l)" APKs)"
# rm -f APKINDEX.tar.gz APKINDEX.tar.gz.sig
# if ls *.apk >/dev/null 2>&1; then
#   apk index -o APKINDEX.tar.gz *.apk
#   abuild-sign -k "$KEY" APKINDEX.tar.gz || { echo "Signing failed" >&2; exit 1; }
# else
#   echo "[builder] No APKs to index"
# fi
BUILDER_EOF

chmod +x /tmp/run-as-builder.sh
chown -R builder:builder /workspace "$OUTPUT_DIR"

su - builder -s /bin/sh -c "ABUILD_PRIVKEY='${ABUILD_PRIVKEY:-}' PKGS='${PKGS}' OUTPUT_DIR='${OUTPUT_DIR}' /tmp/run-as-builder.sh"

cp /home/builder/.abuild/*.pub /workspace/keys/alpine.pub 2>/dev/null
echo "[common] Final contents of $OUTPUT_DIR:"; ls -la "$OUTPUT_DIR"
echo "[common] Done"
