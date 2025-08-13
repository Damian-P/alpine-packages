#!/usr/bin/env bash
set -euo pipefail

# Script pour réactiver GitHub Pages après nettoyage
# Utilise l'API GitHub pour reconfigurer Pages

echo "=== Réactivation des GitHub Pages ==="

# Vérifier que gh CLI est installé
if ! command -v gh >/dev/null 2>&1; then
  echo "Erreur: GitHub CLI (gh) n'est pas installé"
  echo "Installation: https://cli.github.com/"
  exit 1
fi

# Vérifier l'authentification
if ! gh auth status >/dev/null 2>&1; then
  echo "Erreur: Non authentifié avec GitHub CLI"
  echo "Exécutez: gh auth login"
  exit 1
fi

REPO="Damian-P/alpine-packages"

echo "1. Vérification du statut actuel des Pages..."
pages_status=$(gh api repos/$REPO/pages 2>/dev/null || echo "disabled")

if [ "$pages_status" = "disabled" ]; then
  echo "ℹ Pages actuellement désactivées"
else
  echo "ℹ Pages actuellement actives"
fi

echo "2. Réactivation des GitHub Pages..."
cat > /tmp/pages_config.json << EOF
{
  "source": {
    "branch": "gh-pages",
    "path": "/"
  }
}
EOF

if gh api --method POST repos/$REPO/pages -F @/tmp/pages_config.json; then
  echo "✓ GitHub Pages réactivées avec succès"
else
  echo "ℹ Tentative de mise à jour de la configuration..."
  gh api --method PUT repos/$REPO/pages -F @/tmp/pages_config.json || {
    echo "⚠ Impossible de réactiver via API, réactivation manuelle requise"
    echo ""
    echo "Réactivation manuelle:"
    echo "1. Allez sur: https://github.com/$REPO/settings/pages"
    echo "2. Dans 'Source', sélectionnez 'Deploy from a branch'"
    echo "3. Sélectionnez 'gh-pages' et '/ (root)'"
    echo "4. Cliquez 'Save'"
    echo ""
    echo "Puis attendez que le workflow génère la branche gh-pages."
    exit 1
  }
fi

rm -f /tmp/pages_config.json

echo "3. Déclenchement d'un build pour créer la branche gh-pages..."
# Le workflow va créer automatiquement la branche gh-pages

echo ""
echo "=== Réactivation terminée ==="
echo ""
echo "✓ GitHub Pages configurées pour utiliser gh-pages"
echo "ℹ La branche gh-pages sera créée automatiquement par le prochain workflow"
echo ""
echo "Le site sera disponible à:"
echo "https://damian-p.github.io/alpine-packages/"
echo ""
echo "Statut Pages: https://github.com/$REPO/settings/pages"
echo "Actions: https://github.com/$REPO/actions"
