#!/bin/sh

# Utilitaires pour le repository Alpine Linux
# Support pour Alpine edge uniquement

set -e

# Configuration
SUPPORTED_ARCHS="x86_64 aarch64"

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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

show_help() {
    echo "Usage: $0 <command>"
    echo ""
    echo "Commandes disponibles:"
    echo "  build-all       Construire tous les packages pour toutes les architectures"
    echo "  clean           Nettoyer tous les packages construits"
    echo "  serve           Servir le repository localement (port 8080)"
    echo "  status          Afficher le statut du repository"
    echo "  help            Afficher cette aide"
    echo ""
    echo "Exemples:"
    echo "  $0 build-all    # Construire pour x86_64 et aarch64"
    echo "  $0 serve        # Servir sur http://localhost:8080"
    echo ""
}

build_all() {
    log_info "Construction pour toutes les architectures supportées..."
    
    for arch in $SUPPORTED_ARCHS; do
        log_info "Construction pour $arch..."
        ./build.sh -a "$arch"
        
        if [ $? -eq 0 ]; then
            log_success "Construction $arch terminée"
        else
            log_error "Échec de la construction pour $arch"
        fi
        echo ""
    done
    
    log_success "Construction terminée pour toutes les architectures"
    show_status
}

clean_all() {
    log_info "Nettoyage de tous les packages..."
    rm -rf packages/
    log_success "Nettoyage terminé"
}

serve_local() {
    if [ ! -d "packages" ]; then
        log_warning "Aucun package trouvé. Exécutez d'abord la construction."
        return 1
    fi
    
    # Créer une structure simple pour le serveur
    mkdir -p www
    
    # Copier les packages
    if [ -d "packages" ]; then
        cp -r packages/* www/ 2>/dev/null || true
    fi
    
    # Créer une page d'index simple
    cat > www/index.html << EOF
<!DOCTYPE html>
<html>
<head>
    <title>Repository Alpine Linux Local</title>
    <meta charset="utf-8">
    <style>
        body { font-family: Arial, sans-serif; margin: 2em; background: #f5f5f5; }
        .container { max-width: 800px; margin: 0 auto; background: white; padding: 2em; border-radius: 8px; }
        .header { text-align: center; margin-bottom: 2em; }
        .arch-section { margin: 1em 0; padding: 1em; background: #f8f9fa; border-radius: 4px; }
        .package-list { list-style: none; padding: 0; }
        .package-list li { padding: 0.5em; margin: 0.3em 0; background: white; border-radius: 4px; }
        a { color: #007acc; text-decoration: none; }
        a:hover { text-decoration: underline; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🏔️ Repository Alpine Linux Local</h1>
            <p><strong>Version:</strong> Alpine edge</p>
        </div>
EOF
    
    # Lister les packages par architecture
    for arch in $SUPPORTED_ARCHS; do
        if [ -d "packages/main/$arch" ] && [ "$(ls packages/main/$arch/*.apk 2>/dev/null | wc -l)" -gt "0" ]; then
            package_count=$(ls packages/main/$arch/*.apk | wc -l)
            cat >> www/index.html << EOF
        <div class="arch-section">
            <h2>Architecture: $arch ($package_count packages)</h2>
            <ul class="package-list">
EOF
            for apk in packages/main/$arch/*.apk; do
                if [ -f "$apk" ]; then
                    filename=$(basename "$apk")
                    size=$(ls -lh "$apk" | awk '{print $5}')
                    cat >> www/index.html << EOF
                <li><a href="main/$arch/$filename">$filename</a> <small>($size)</small></li>
EOF
                fi
            done
            cat >> www/index.html << EOF
            </ul>
        </div>
EOF
        fi
    done
    
    cat >> www/index.html << EOF
        <div style="margin-top: 2em; text-align: center; color: #666;">
            <p>Pour utiliser ce repository:</p>
            <pre style="background: #f0f0f0; padding: 1em; border-radius: 4px; text-align: left;">echo "http://localhost:8080/main" >> /etc/apk/repositories
apk update</pre>
        </div>
    </div>
</body>
</html>
EOF
    
    log_info "Démarrage du serveur local sur le port 8080..."
    log_info "Repository disponible sur: http://localhost:8080"
    log_info "Appuyez sur Ctrl+C pour arrêter"
    echo ""
    
    # Utiliser Python si disponible, sinon essayer d'autres options
    if command -v python3 >/dev/null; then
        cd www && python3 -m http.server 8080
    elif command -v python >/dev/null; then
        cd www && python -m SimpleHTTPServer 8080
    elif command -v php >/dev/null; then
        cd www && php -S localhost:8080
    else
        log_error "Aucun serveur web disponible (python, php). Installez l'un d'eux."
    fi
}

show_status() {
    echo ""
    log_info "=== STATUS DU REPOSITORY ==="
    echo ""
    
    total_packages=0
    
    for arch in $SUPPORTED_ARCHS; do
        if [ -d "packages/main/$arch" ]; then
            package_count=$(ls packages/main/$arch/*.apk 2>/dev/null | wc -l || echo "0")
            total_packages=$((total_packages + package_count))
            
            if [ "$package_count" -gt "0" ]; then
                log_success "Architecture $arch: $package_count packages"
                for apk in packages/main/$arch/*.apk; do
                    if [ -f "$apk" ]; then
                        size=$(ls -lh "$apk" | awk '{print $5}')
                        echo "  - $(basename "$apk") ($size)"
                    fi
                done
            else
                log_warning "Architecture $arch: aucun package"
            fi
            echo ""
        else
            log_warning "Architecture $arch: répertoire non trouvé"
            echo ""
        fi
    done
    
    if [ "$total_packages" -gt "0" ]; then
        log_success "Total: $total_packages packages construits"
    else
        log_warning "Aucun package construit. Utilisez './build.sh' ou './utils.sh build-all'"
    fi
    
    echo ""
    log_info "=== COMMANDES UTILES ==="
    echo "  Construction:     ./build.sh -a x86_64"
    echo "  Tout construire:  ./utils.sh build-all"
    echo "  Servir:          ./utils.sh serve"
    echo "  Nettoyer:        ./utils.sh clean"
    echo ""
}

# Commande principale
case "${1:-help}" in
    build-all)
        build_all
        ;;
    clean)
        clean_all
        ;;
    serve)
        serve_local
        ;;
    status)
        show_status
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        log_error "Commande inconnue: $1"
        show_help
        ;;
esac
