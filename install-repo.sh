#!/bin/sh

# Script d'installation du repository Alpine Linux personnalisé
# Usage: ./install-repo.sh [options]

set -e

REPO_OWNER="Damian-P"
REPO_NAME="alpine-packages"
DEFAULT_VERSION="edge"
DEFAULT_ARCH="x86_64"

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
    echo "  -v, --version VERSION    Alpine version (edge uniquement) [default: $DEFAULT_VERSION]"
    echo "  -a, --arch ARCH         Architecture (x86_64, aarch64) [default: $DEFAULT_ARCH]"
    echo "  -m, --method METHOD     Méthode d'installation (pages, container, release) [default: pages]"
    echo "  -h, --help             Afficher cette aide"
    echo ""
    echo "Exemples:"
    echo "  $0                      # Installer le repo par défaut (Alpine edge x86_64)"
    echo "  $0 -a aarch64          # Installer pour Alpine edge aarch64"
    echo "  $0 -m container         # Utiliser les containers Docker"
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

check_alpine() {
    if [ ! -f /etc/alpine-release ]; then
        log_error "Ce script doit être exécuté sur Alpine Linux"
    fi
    
    current_version=$(cat /etc/alpine-release)
    log_info "Alpine Linux version détectée: $current_version"
}

install_pages_repo() {
    local version="$1"
    local arch="$2"
    
    log_info "Installation du repository via GitHub Pages"
    
    # URL du repository GitHub Pages
    repo_url="https://${REPO_OWNER}.github.io/${REPO_NAME}/v${version}/main"
    
    # Vérifier si le repository est accessible
    if command -v curl >/dev/null; then
        if ! curl -s --head "$repo_url/" | grep -q "200 OK"; then
            log_warning "Le repository GitHub Pages n'est pas encore disponible"
            log_info "Tentative avec la méthode container..."
            install_container_repo "$version" "$arch"
            return
        fi
    fi
    
    # Ajouter le repository
    echo "$repo_url" >> /etc/apk/repositories
    log_success "Repository ajouté: $repo_url"
    
    # Mettre à jour la base de packages
    apk update
    log_success "Base de packages mise à jour"
}

install_container_repo() {
    local version="$1"
    local arch="$2"
    
    log_info "Installation du repository via container Docker multi-architecture"
    
    # Vérifier si Docker est disponible
    if ! command -v docker >/dev/null; then
        log_error "Docker n'est pas installé. Installez Docker ou utilisez une autre méthode."
    fi
    
    # Nom du container (simplifié pour multi-architecture)
    container_name="alpine-repo-${version}"
    image_name="ghcr.io/${REPO_OWNER}/${REPO_NAME}/alpine-repo:latest"
    
    log_info "Téléchargement de l'image multi-architecture: $image_name"
    
    # Arrêter le container existant si il existe
    docker stop "$container_name" 2>/dev/null || true
    docker rm "$container_name" 2>/dev/null || true
    
    # Lancer le container
    if docker run -d --name "$container_name" -p 8080:80 "$image_name"; then
        log_success "Container lancé: $container_name"
        log_info "Repository accessible sur: http://localhost:8080"
        
        # Ajouter le repository local
        echo "http://localhost:8080/v${version}/main" >> /etc/apk/repositories
        log_success "Repository local ajouté"
        
        # Attendre que le service soit prêt
        log_info "Attente du démarrage du service..."
        sleep 3
        
        # Mettre à jour
        apk update
        log_success "Base de packages mise à jour"
    else
        log_error "Impossible de lancer le container"
    fi
}

download_release_packages() {
    local version="$1"
    local arch="$2"
    
    log_info "Téléchargement des packages depuis GitHub Releases"
    
    # URL de base GitHub
    base_url="https://github.com/${REPO_OWNER}/${REPO_NAME}/releases/latest/download"
    
    # Créer un répertoire temporaire
    temp_dir=$(mktemp -d)
    cd "$temp_dir"
    
    log_info "Téléchargement de l'archive: alpine-packages-${version}-${arch}.tar.gz"
    
    # Télécharger l'archive
    if command -v curl >/dev/null; then
        curl -L -o "packages.tar.gz" "${base_url}/alpine-packages-${version}-${arch}.tar.gz"
    elif command -v wget >/dev/null; then
        wget -O "packages.tar.gz" "${base_url}/alpine-packages-${version}-${arch}.tar.gz"
    else
        log_error "curl ou wget requis pour le téléchargement"
    fi
    
    # Extraire
    tar -xzf packages.tar.gz
    
    log_success "Packages téléchargés dans: $temp_dir"
    echo "Vous pouvez installer manuellement avec: apk add $temp_dir/*.apk"
}

# Valeurs par défaut
VERSION="$DEFAULT_VERSION"
ARCH="$DEFAULT_ARCH"
METHOD="pages"

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
        -m|--method)
            METHOD="$2"
            shift 2
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

case "$METHOD" in
    pages|container|release) ;;
    *) log_error "Méthode non supportée: $METHOD. Utilisez: pages, container, ou release" ;;
esac

# Vérification des permissions root
if [ "$(id -u)" -ne 0 ] && [ "$METHOD" != "release" ]; then
    log_error "Ce script doit être exécuté en tant que root (sauf pour la méthode 'release')"
fi

# Vérifier qu'on est sur Alpine Linux (sauf pour release)
if [ "$METHOD" != "release" ]; then
    check_alpine
fi

log_info "Configuration:"
log_info "  Version Alpine: $VERSION"
log_info "  Architecture: $ARCH"
log_info "  Méthode: $METHOD"
echo ""

# Installer selon la méthode choisie
case "$METHOD" in
    pages)
        install_pages_repo "$VERSION" "$ARCH"
        ;;
    container)
        install_container_repo "$VERSION" "$ARCH"
        ;;
    release)
        download_release_packages "$VERSION" "$ARCH"
        ;;
esac

log_success "Installation terminée !"

if [ "$METHOD" = "container" ]; then
    echo ""
    log_info "Pour arrêter le container:"
    echo "  docker stop alpine-repo-${VERSION}"
    echo ""
    log_info "Pour redémarrer le container:"
    echo "  docker start alpine-repo-${VERSION}"
fi

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
    echo "  -v, --version VERSION    Alpine version (3.20, 3.22, edge) [default: $DEFAULT_VERSION]"
    echo "  -a, --arch ARCH         Architecture (x86_64, aarch64) [default: $DEFAULT_ARCH]"
    echo "  -m, --method METHOD     Méthode d'installation (pages, container, release) [default: pages]"
    echo "  -h, --help             Afficher cette aide"
    echo ""
    echo "Exemples:"
    echo "  $0                      # Installer le repo par défaut (Alpine 3.22 x86_64)"
    echo "  $0 -v edge -a aarch64   # Installer pour Alpine edge aarch64"
    echo "  $0 -m container         # Utiliser les containers Docker"
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

check_alpine() {
    if [ ! -f /etc/alpine-release ]; then
        log_error "Ce script doit être exécuté sur Alpine Linux"
    fi
    
    current_version=$(cat /etc/alpine-release)
    log_info "Alpine Linux version détectée: $current_version"
}

install_pages_repo() {
    local version="$1"
    local arch="$2"
    
    log_info "Installation du repository via GitHub Pages"
    
    # URL du repository GitHub Pages
    repo_url="https://${REPO_OWNER}.github.io/${REPO_NAME}/v${version}/main"
    
    # Vérifier si le repository est accessible
    if command -v curl >/dev/null; then
        if ! curl -s --head "$repo_url/" | grep -q "200 OK"; then
            log_warning "Le repository GitHub Pages n'est pas encore disponible"
            log_info "Tentative avec la méthode container..."
            install_container_repo "$version" "$arch"
            return
        fi
    fi
    
    # Ajouter le repository
    echo "$repo_url" >> /etc/apk/repositories
    log_success "Repository ajouté: $repo_url"
    
    # Mettre à jour la base de packages
    apk update
    log_success "Base de packages mise à jour"
}

install_container_repo() {
    local version="$1"
    local arch="$2"
    
    log_info "Installation du repository via container Docker"
    
    # Vérifier si Docker est disponible
    if ! command -v docker >/dev/null; then
        log_error "Docker n'est pas installé. Installez Docker ou utilisez une autre méthode."
    fi
    
    # Nom du container
    container_name="alpine-repo-${version}-${arch}"
    image_name="ghcr.io/${REPO_OWNER}/${REPO_NAME}/alpine-repo:${version}-${arch}"
    
    log_info "Téléchargement de l'image: $image_name"
    
    # Arrêter le container existant si il existe
    docker stop "$container_name" 2>/dev/null || true
    docker rm "$container_name" 2>/dev/null || true
    
    # Lancer le container
    if docker run -d --name "$container_name" -p 8080:80 "$image_name"; then
        log_success "Container lancé: $container_name"
        log_info "Repository accessible sur: http://localhost:8080"
        
        # Ajouter le repository local
        echo "http://localhost:8080/v${version}/main" >> /etc/apk/repositories
        log_success "Repository local ajouté"
        
        # Attendre que le service soit prêt
        log_info "Attente du démarrage du service..."
        sleep 3
        
        # Mettre à jour
        apk update
        log_success "Base de packages mise à jour"
    else
        log_error "Impossible de lancer le container"
    fi
}

download_release_packages() {
    local version="$1"
    local arch="$2"
    
    log_info "Téléchargement des packages depuis GitHub Releases"
    
    # URL de base GitHub
    base_url="https://github.com/${REPO_OWNER}/${REPO_NAME}/releases/latest/download"
    
    # Créer un répertoire temporaire
    temp_dir=$(mktemp -d)
    cd "$temp_dir"
    
    log_info "Téléchargement de l'archive: alpine-packages-${version}-${arch}.tar.gz"
    
    # Télécharger l'archive
    if command -v curl >/dev/null; then
        curl -L -o "packages.tar.gz" "${base_url}/alpine-packages-${version}-${arch}.tar.gz"
    elif command -v wget >/dev/null; then
        wget -O "packages.tar.gz" "${base_url}/alpine-packages-${version}-${arch}.tar.gz"
    else
        log_error "curl ou wget requis pour le téléchargement"
    fi
    
    # Extraire
    tar -xzf packages.tar.gz
    
    log_success "Packages téléchargés dans: $temp_dir"
    echo "Vous pouvez installer manuellement avec: apk add $temp_dir/${arch}/*.apk"
}

# Valeurs par défaut
VERSION="$DEFAULT_VERSION"
ARCH="$DEFAULT_ARCH"
METHOD="pages"

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
        -m|--method)
            METHOD="$2"
            shift 2
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
    3.20|3.22|edge) ;;
    *) log_error "Version non supportée: $VERSION. Utilisez: 3.20, 3.22, ou edge" ;;
esac

case "$ARCH" in
    x86_64|aarch64) ;;
    *) log_error "Architecture non supportée: $ARCH. Utilisez: x86_64 ou aarch64" ;;
esac

case "$METHOD" in
    pages|container|release) ;;
    *) log_error "Méthode non supportée: $METHOD. Utilisez: pages, container, ou release" ;;
esac

# Vérification des permissions root
if [ "$(id -u)" -ne 0 ] && [ "$METHOD" != "release" ]; then
    log_error "Ce script doit être exécuté en tant que root (sauf pour la méthode 'release')"
fi

# Vérifier qu'on est sur Alpine Linux (sauf pour release)
if [ "$METHOD" != "release" ]; then
    check_alpine
fi

log_info "Configuration:"
log_info "  Version Alpine: $VERSION"
log_info "  Architecture: $ARCH"
log_info "  Méthode: $METHOD"
echo ""

# Installer selon la méthode choisie
case "$METHOD" in
    pages)
        install_pages_repo "$VERSION" "$ARCH"
        ;;
    container)
        install_container_repo "$VERSION" "$ARCH"
        ;;
    release)
        download_release_packages "$VERSION" "$ARCH"
        ;;
esac

log_success "Installation terminée !"

if [ "$METHOD" = "container" ]; then
    echo ""
    log_info "Pour arrêter le container:"
    echo "  docker stop alpine-repo-${VERSION}-${ARCH}"
    echo ""
    log_info "Pour redémarrer le container:"
    echo "  docker start alpine-repo-${VERSION}-${ARCH}"
fi
