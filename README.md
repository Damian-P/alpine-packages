# 🏔️ Alpine Linux Packages Repository

Repository personnalisé de packages Alpine Linux avec support multi-versions et multi-architectures, hébergé entièrement sur GitHub.

## 📦 **Packages disponibles**

- **incus-feature** : Version avec fonctionnalités avancées d'Incus
- **incus-ui** : Interface utilisateur web pour Incus avec patches personnalisés

## 🏗️ **Versions supportées**

| Version Alpine | x86_64 | aarch64 | Status |
|----------------|--------|---------|--------|
| 3.20 | ✅ | ✅ | Stable |
| 3.22 | ✅ | ✅ | Stable |
| edge | ✅ | ✅ | Rolling |

## 🚀 **Méthodes d'hébergement GitHub**

### 1. 🌐 **GitHub Pages** *(Recommandé)*
Repository APK accessible directement via HTTPS.

**URL**: https://damian-p.github.io/alpine-packages/

```bash
# Installation automatique
curl -fsSL https://raw.githubusercontent.com/Damian-P/alpine-packages/main/install-repo.sh | sh

# Ou installation manuelle
echo "https://damian-p.github.io/alpine-packages/v3.22/main" >> /etc/apk/repositories
apk update
```

### 2. 🐳 **GitHub Container Registry**
Images Docker contenant le repository complet.

```bash
# Lancer le serveur de repository
docker run -p 8080:80 ghcr.io/damian-p/alpine-packages/alpine-repo:3.22-x86_64

# Puis ajouter le repository
echo "http://localhost:8080/v3.22/main" >> /etc/apk/repositories
apk update
```

**Images disponibles**:
- `ghcr.io/damian-p/alpine-packages/alpine-repo:3.20-x86_64`
- `ghcr.io/damian-p/alpine-packages/alpine-repo:3.20-aarch64`
- `ghcr.io/damian-p/alpine-packages/alpine-repo:3.22-x86_64`
- `ghcr.io/damian-p/alpine-packages/alpine-repo:3.22-aarch64`
- `ghcr.io/damian-p/alpine-packages/alpine-repo:edge-x86_64`
- `ghcr.io/damian-p/alpine-packages/alpine-repo:edge-aarch64`

### 3. 📋 **GitHub Releases**
Téléchargement direct des packages individuels ou par archive.

```bash
# Télécharger une archive complète
curl -L -o packages.tar.gz \
  "https://github.com/Damian-P/alpine-packages/releases/latest/download/alpine-packages-3.22-x86_64.tar.gz"

# Ou télécharger des packages individuels depuis la page des releases
```

### 4. 📁 **GitHub Actions Artifacts**
Accès temporaire aux builds via l'interface GitHub (30 jours).

## 🛠️ **Script d'installation**

Le script `install-repo.sh` automatise l'installation selon différentes méthodes :

```bash
# Installation par défaut (Pages + Alpine 3.22 x86_64)
./install-repo.sh

# Spécifier version et architecture
./install-repo.sh -v edge -a aarch64

# Utiliser les containers Docker
./install-repo.sh -m container

# Télécharger depuis les releases
./install-repo.sh -m release

# Aide complète
./install-repo.sh --help
```

## 🔧 **Build local**

```bash
# Build pour la version par défaut
./build.sh

# Build pour version et architecture spécifiques
./build.sh -v 3.22 -a x86_64

# Build pour toutes les versions
./utils.sh build-all

# Servir localement
./utils.sh serve
```

## 🤖 **Automatisation GitHub Actions**

Le workflow se déclenche automatiquement sur :
- Push vers `main` avec modifications dans `main/` ou `.github/workflows/`
- Pull requests
- Déclenchement manuel

**Processus automatisé** :
1. **Build multi-plateforme** : Compilation pour 6 combinaisons (3 versions × 2 architectures)
2. **Container Registry** : Publication des images Docker
3. **GitHub Pages** : Déploiement du site web avec repository APK
4. **GitHub Releases** : Publication des archives et packages individuels
5. **Artifacts** : Stockage temporaire des builds

## 📊 **Status des builds**

[![Build Alpine APK Packages](https://github.com/Damian-P/alpine-packages/actions/workflows/build-packages.yml/badge.svg)](https://github.com/Damian-P/alpine-packages/actions/workflows/build-packages.yml)

## 📈 **Utilisation des packages**

Une fois le repository ajouté :

```bash
# Rechercher les packages disponibles
apk search incus

# Installer incus-feature
apk add incus-feature

# Installer l'interface web
apk add incus-ui

# Voir les informations d'un package
apk info incus-feature
```

## 🗂️ **Structure du projet**

```
alpine-packages/
├── .github/workflows/
│   └── build-packages.yml      # Workflow automatisé
├── main/                       # Packages sources
│   ├── incus-feature/          # Package incus avec features
│   ├── incus-next/            # Version next (désactivée)
│   └── incus-ui/              # Interface web
├── build.sh                   # Script de build local
├── install-repo.sh           # Script d'installation
├── utils.sh                  # Utilitaires
└── README.md                 # Cette documentation
```

## 🔐 **Signature des packages**

Tous les packages sont signés automatiquement avec les clés générées par `abuild`. Pour la production, il est recommandé de :

1. Générer des clés de signature persistantes
2. Les stocker comme secrets GitHub
3. Les utiliser dans le workflow

## 🤝 **Contribution**

1. Forkez le projet
2. Créez une branche pour votre fonctionnalité
3. Commitez vos changements
4. Poussez vers la branche
5. Ouvrez une Pull Request

## 📝 **License**

Ce projet est distribué sous license MIT. Voir le fichier `LICENSE` pour plus de détails.

---

**Généré automatiquement** par GitHub Actions • [Code source](https://github.com/Damian-P/alpine-packages)