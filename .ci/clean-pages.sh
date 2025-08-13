#!/usr/bin/env bash
set -euo pipefail

# Script pour nettoyer complètement les GitHub Pages
# Supprime la branche gh-pages et force un redéploiement propre

echo "=== Nettoyage complet des GitHub Pages ==="

# Vérifier qu'on est sur la branche main
current_branch=$(git branch --show-current)
if [ "$current_branch" != "main" ]; then
  echo "Erreur: Ce script doit être exécuté depuis la branche main"
  exit 1
fi

echo "Branche actuelle: $current_branch"

# Sauvegarder les modifications locales si nécessaire
if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "Attention: Des modifications locales non committées ont été détectées"
  read -p "Voulez-vous continuer? Les modifications ne seront pas perdues. [y/N] " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Opération annulée"
    exit 1
  fi
fi

echo "1. Fetch des dernières modifications..."
git fetch origin

echo "2. Suppression de la branche gh-pages locale (si elle existe)..."
git branch -D gh-pages 2>/dev/null || echo "Branche gh-pages locale non trouvée"

echo "3. Suppression de la branche gh-pages distante..."
if git push origin --delete gh-pages 2>/dev/null; then
  echo "✓ Branche gh-pages supprimée avec succès"
else
  echo "ℹ Branche gh-pages distante non trouvée ou déjà supprimée"
fi

echo "4. Nettoyage des artefacts locaux..."
rm -rf output/ public/ previous-packages/ 2>/dev/null || true
echo "✓ Dossiers temporaires supprimés"

echo "5. Force d'un nouveau déploiement..."
echo "Pour déclencher un nouveau déploiement propre, nous allons faire un commit vide:"

# Créer un commit vide pour forcer le redéploiement
commit_message="Clean rebuild: reset GitHub Pages deployment

- Removed gh-pages branch for clean start  
- All packages will be rebuilt from scratch
- APKINDEX will be properly signed and published"

git commit --allow-empty -m "$commit_message"

echo "6. Push vers main pour déclencher le workflow..."
git push origin main

echo ""
echo "=== Nettoyage terminé ==="
echo ""
echo "✓ La branche gh-pages a été supprimée"
echo "✓ Les artefacts locaux ont été nettoyés"  
echo "✓ Un commit vide a été créé pour forcer le redéploiement"
echo "✓ Le push a déclenché le workflow de build"
echo ""
echo "Le nouveau site sera disponible dans quelques minutes à:"
echo "https://damian-p.github.io/alpine-packages/"
echo ""
echo "Vous pouvez suivre le progrès sur:"
echo "https://github.com/Damian-P/alpine-packages/actions"
