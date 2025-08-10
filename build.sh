#!/bin/sh

# Script de construction simple pour packages Alpine Linux
# Support pour Alpine edge uniquement avec multi-architecture

set -e

# Configuration par défaut
DEFAULT_VERSION="edge"
DEFAULT_ARCH=$(uname -m)

# Couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_usage() {
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  -v, --version VERSION    Version Alpine (edge uniquement) [default: $DEFAULT_VERSION]"
    echo "  -a, --arch ARCH         Architecture (x86_64, aarch64) [default: $DEFAULT_ARCH]"
    echo "  -c, --clean             Nettoyer avant la construction"
    echo "  -h, --help             Afficher cette aide"
    echo ""
    echo "Exemples:"
    echo "  $0                      # Construction par défaut (edge, architecture actuelle)"
    echo "  $0 -a x86_64           # Construction pour x86_64"
    echo "  $0 -a aarch64          # Construction pour aarch64"
    echo "  $0 -c                  # Nettoyer puis construire"
    echo ""
}

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

# Valeurs par défaut
VERSION="$DEFAULT_VERSION"
ARCH="$DEFAULT_ARCH"
CLEAN=false

# Parser les arguments
while [ $# -gt 0 ]; do
    case $1 in
        -v|--version)
            VERSION="$2"
            shift 2
            ;;
        -a|--arch)
            ARCH="$2"
            shift 2
            ;;
        -c|--clean)
            CLEAN=true
            shift
            ;;
        -h|--help)
            print_usage
            exit 0
            ;;
        *)
            log_error "Option inconnue: $1"
            ;;
    esac
done

# Validation
case "$VERSION" in
    edge) ;;
    *) log_error "Version non supportée: $VERSION. Seule 'edge' est supportée." ;;
esac

case "$ARCH" in
    x86_64|aarch64) ;;
    *) log_error "Architecture non supportée: $ARCH. Utilisez: x86_64 ou aarch64" ;;
esac

# Nettoyer si demandé
if [ "$CLEAN" = true ]; then
    log_info "Nettoyage des packages existants..."
    rm -rf packages/
    log_success "Nettoyage terminé"
fi

# Vérifier Docker
if ! command -v docker >/dev/null; then
    log_error "Docker est requis pour la construction. Veuillez l'installer."
fi

# Déterminer la plateforme Docker
case "$ARCH" in
    "x86_64") DOCKER_PLATFORM="linux/amd64" ;;
    "aarch64") DOCKER_PLATFORM="linux/arm64" ;;
esac

log_info "Configuration de construction:"
log_info "  Version Alpine: $VERSION"
log_info "  Architecture: $ARCH"
log_info "  Plateforme Docker: $DOCKER_PLATFORM"
echo ""

# Créer les répertoires de sortie
mkdir -p "packages/main/$ARCH"

log_info "Démarrage de la construction..."

# Construction avec Docker
docker run --rm \
    --platform="$DOCKER_PLATFORM" \
    --volume "$(pwd)/main:/home/packager/main" \
    --volume "$(pwd)/packages:/home/packager/packages" \
    alpine:"$VERSION" sh -c "
        set -eux
        
        # Installation des dépendances
        apk add --no-cache sudo build-base alpine-sdk git
        
        # Configuration de l'utilisateur packager
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
                
                echo \"Construction du package: \$pkg pour Alpine $VERSION ($ARCH)\"
                cd /home/packager/main/\$pkg
                
                abuild checksum || true
                REPODEST=/home/packager/packages abuild -r
                
                cd /home/packager/main
            done
            
            # Génération de l'index du repository
            cd /home/packager/packages/main/$ARCH
            if ls *.apk >/dev/null 2>&1; then
                apk index -o APKINDEX.tar.gz *.apk
                abuild-sign -k /home/packager/.abuild/*.rsa.priv APKINDEX.tar.gz
                echo \"Index du repository créé avec succès\"
            else
                echo \"Aucun package construit\"
            fi
        '
    "

# Vérifier les résultats
if [ -d "packages/main/$ARCH" ] && [ "$(ls packages/main/$ARCH/*.apk 2>/dev/null | wc -l)" -gt "0" ]; then
    package_count=$(ls packages/main/$ARCH/*.apk | wc -l)
    log_success "Construction terminée avec succès !"
    log_info "Packages construits: $package_count"
    echo ""
    echo "Packages disponibles dans packages/main/$ARCH/:"
    for apk in packages/main/$ARCH/*.apk; do
        if [ -f "$apk" ]; then
            size=$(ls -lh "$apk" | awk '{print $5}')
            echo "  - $(basename "$apk") ($size)"
        fi
    done
else
    log_warning "Aucun package n'a été construit"
fi

echo ""
log_info "Pour servir localement:"
echo "  ./utils.sh serve"
echo ""
log_info "Pour construire toutes les architectures:"
echo "  ./utils.sh build-all"