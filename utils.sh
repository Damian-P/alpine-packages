#!/bin/bash
# Script utilitaire simplifié pour gérer les packages Alpine

set -euo pipefail

show_help() {
    cat << EOF
Usage: $0 COMMAND [OPTIONS]

COMMANDS:
    build       Construire les packages pour toutes les versions
    clean       Nettoyer les artefacts
    serve       Servir un référentiel local
    status      Afficher le statut

EXEMPLES:
    $0 build            # Construire pour toutes les versions Alpine
    $0 serve 3.22       # Servir Alpine 3.22 localement
    $0 clean            # Nettoyer les artefacts
EOF
}

cmd_build() {
    echo "🏗️  Construction pour toutes les versions Alpine supportées..."
    
    VERSIONS="3.20 3.22 edge"
    ARCHITECTURES="x86_64 aarch64"
    
    for version in $VERSIONS; do
        for arch in $ARCHITECTURES; do
            echo "📦 Construction Alpine $version pour $arch..."
            if ./build.sh -v "$version" -a "$arch"; then
                echo "✅ Succès: Alpine $version ($arch)"
            else
                echo "❌ Échec: Alpine $version ($arch)"
            fi
        done
    done
    
    echo "🎉 Construction terminée!"
}

cmd_clean() {
    echo "🧹 Nettoyage des artefacts..."
    rm -rf packages/main/*
    echo "✅ Nettoyage terminé"
}

cmd_serve() {
    local version="${1:-3.22}"
    local port="${2:-8080}"
    
    echo "🌐 Démarrage du serveur pour Alpine $version sur le port $port..."
    
    if [ ! -d "packages" ]; then
        echo "❌ Aucun package trouvé. Lancez d'abord la construction."
        exit 1
    fi
    
    cd packages
    echo "📡 Serveur disponible sur http://localhost:$port"
    python3 -m http.server "$port" 2>/dev/null || python -m SimpleHTTPServer "$port"
}

cmd_status() {
    echo "📊 Statut du référentiel Alpine Packages"
    echo
    
    echo "📂 Structure:"
    if [ -d "main" ]; then
        pkgs=$(ls -d main/*/ 2>/dev/null | wc -l)
        echo "  ✅ Répertoire main: $pkgs packages"
    else
        echo "  ❌ Répertoire main manquant"
    fi
    
    echo
    echo "📦 Packages construits:"
    for version in 3.20 3.22 edge; do
        for arch in x86_64 aarch64; do
            pkg_dir="packages/main/$arch"
            if [ -d "$pkg_dir" ] && [ -n "$(ls "$pkg_dir"/*.apk 2>/dev/null || true)" ]; then
                count=$(ls "$pkg_dir"/*.apk 2>/dev/null | wc -l)
                echo "  ✅ $version-$arch: $count packages"
            else
                echo "  ❌ $version-$arch: non construit"
            fi
        done
    done
}

case "${1:-}" in
    build) cmd_build ;;
    clean) cmd_clean ;;
    serve) shift; cmd_serve "$@" ;;
    status) cmd_status ;;
    help|--help|-h) show_help ;;
    *) echo "❌ Commande inconnue: ${1:-}"; show_help; exit 1 ;;
esac
