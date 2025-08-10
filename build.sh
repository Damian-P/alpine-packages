#!/bin/sh
# Script de construction simple pour packages Alpine Linux
# Support pour multiples versions Alpine et architectures

# Configuration par défaut
ALPINE_VERSION="${ALPINE_VERSION:-3.22}"
ARCH="${ARCH:-$(uname -m)}"

# Aide
show_help() {
    cat << EOF
Usage: $0 [OPTIONS]

OPTIONS:
    -v, --version VERSION   Version Alpine (3.20, 3.22, edge) [défaut: $ALPINE_VERSION]
    -a, --arch ARCH         Architecture (x86_64, aarch64) [défaut: $ARCH]
    -h, --help              Afficher cette aide

EXEMPLES:
    $0                      # Construction par défaut (Alpine $ALPINE_VERSION, $ARCH)
    $0 -v edge -a aarch64   # Alpine edge pour ARM64
    $0 -v 3.20              # Alpine 3.20

VARIABLES D'ENVIRONNEMENT:
    ALPINE_VERSION          Version Alpine Linux
    ARCH                    Architecture de construction
EOF
}

# Analyse des arguments
while [ $# -gt 0 ]; do
    case $1 in
        -v|--version) ALPINE_VERSION="$2"; shift 2 ;;
        -a|--arch) ARCH="$2"; shift 2 ;;
        -h|--help) show_help; exit 0 ;;
        *) echo "Option inconnue: $1"; show_help; exit 1 ;;
    esac
done

# Validation de l'architecture
case "$ARCH" in
    x86_64) DOCKER_PLATFORM="linux/amd64" ;;
    aarch64) DOCKER_PLATFORM="linux/arm64" ;;
    *) echo "Erreur: Architecture non supportée: $ARCH"; exit 1 ;;
esac

echo "Construction pour Alpine $ALPINE_VERSION ($ARCH)"
echo "Plateforme Docker: $DOCKER_PLATFORM"

# Préparation des répertoires
mkdir -p packages/main/$ARCH

# Construction dans le conteneur
docker run --rm \
    --platform=$DOCKER_PLATFORM \
    --volume "$(pwd)/main:/home/packager/main" \
    --volume "$(pwd)/packages:/home/packager/packages" \
    alpine:$ALPINE_VERSION sh -c "
        set -eux
        apk add sudo build-base alpine-sdk
        adduser -D packager
        addgroup packager abuild
        echo 'packager ALL=(ALL) NOPASSWD:ALL' >/etc/sudoers.d/packager
        
        sudo -u packager sh -c '
            # Génération des clés de signature
            abuild-keygen -n --append --install
            
            cd /home/packager/main
            
            # Construction de chaque package
            for pkg in */; do
                pkg=\${pkg%/}
                case \$pkg in
                    incus-next) continue ;;
                    *) ;;
                esac
                
                echo \"Construction du package: \$pkg\"
                cd /home/packager/main/\$pkg
                
                abuild checksum
                REPODEST=/home/packager/packages abuild -r
                
                cd /home/packager/main
            done
            
            # Génération de l index du référentiel
            cd /home/packager/packages/main/$ARCH
            if ls *.apk >/dev/null 2>&1; then
                apk index -o APKINDEX.tar.gz *.apk
                abuild-sign -k /home/packager/.abuild/*.rsa.priv APKINDEX.tar.gz
            fi
        '
    "

echo "Construction terminée. Packages disponibles dans packages/main/$ARCH/"