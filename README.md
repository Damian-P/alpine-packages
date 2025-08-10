# Alpine Linux Packages Repository

Ce référentiel contient des packages Alpine Linux personnalisés avec publication automatique sur GitHub Packages.

## 📦 Packages Disponibles

- **incus-feature**: Gestionnaire de conteneurs système et de machines virtuelles (branche feature)
- **incus-ui**: Interface utilisateur web pour Incus avec patches personnalisés

## 🏗️ Versions Alpine Supportées

- **Alpine 3.20** - Version stable actuelle
- **Alpine 3.22** - Version stable récente  
- **Alpine edge** - Version de développement

## 🚀 Construction Automatique

Les packages sont automatiquement construits via GitHub Actions pour les architectures `x86_64` et `aarch64` et publiés sur GitHub Packages.

### Utilisation des Packages

#### Configuration Alpine Linux

```bash
# Ajouter le référentiel GitHub Packages (nécessite authentification)
echo "@damian-p https://ghcr.io/v2/damian-p/alpine-packages/alpine-repo/manifests/3.22-x86_64" >> /etc/apk/repositories

# Installer les packages
apk update
apk add incus-feature@damian-p incus-ui@damian-p
```

#### Via Container Registry

```bash
# Récupérer l'image du référentiel pour Alpine 3.22 x86_64
docker pull ghcr.io/damian-p/alpine-packages/alpine-repo:3.22-x86_64

# Servir le référentiel localement
docker run -p 8080:80 ghcr.io/damian-p/alpine-packages/alpine-repo:3.22-x86_64
```

## 🛠️ Construction Locale

### Script de Construction Simple

```bash
# Construction par défaut (Alpine 3.22, architecture courante)
./build.sh

# Construction pour Alpine edge
./build.sh -v edge

# Construction pour ARM64
./build.sh -a aarch64

# Construction pour Alpine 3.20 sur ARM64
./build.sh -v 3.20 -a aarch64

# Aide
./build.sh -h
```

## 📁 Structure du Projet

```
alpine-packages/
├── .github/workflows/          # Workflow GitHub Actions
│   └── build-packages.yml      # Pipeline CI/CD
├── main/                       # Packages du référentiel main
│   ├── incus-feature/          # Package Incus feature branch
│   └── incus-ui/               # Interface web Incus
├── packages/                   # Packages construits localement
│   └── main/
│       ├── x86_64/             # Packages x86_64
│       └── aarch64/            # Packages ARM64
├── build.sh                    # Script de construction simple
└── README.md                   # Cette documentation
```

## 🔧 Variables d'Environnement

| Variable | Description | Défaut |
|----------|-------------|---------|
| `ALPINE_VERSION` | Version d'Alpine Linux | `3.22` |
| `ARCH` | Architecture cible | `$(uname -m)` |

## 📋 Développement

### Ajouter un Nouveau Package

1. Créez un nouveau dossier dans `main/`
2. Ajoutez votre `APKBUILD` et fichiers associés
3. Testez localement avec `./build.sh`
4. Committez et pushez - la CI construira automatiquement

### Modifier un Package Existant

1. Modifiez les fichiers dans `main/nom-du-package/`
2. Mettez à jour la version dans `APKBUILD` si nécessaire
3. Testez avec `./build.sh`
4. Committez et pushez

## � Publication sur GitHub Packages

Les packages sont automatiquement publiés :

1. **Container Registry** : Images Docker par version Alpine et architecture
   - `ghcr.io/damian-p/alpine-packages/alpine-repo:3.20-x86_64`
   - `ghcr.io/damian-p/alpine-packages/alpine-repo:3.22-aarch64`
   - `ghcr.io/damian-p/alpine-packages/alpine-repo:edge-x86_64`

2. **APK Packages** : Packages APK individuels via GitHub Packages API

3. **Artefacts** : Packages téléchargeables via l'interface GitHub

## 🤝 Contribution

1. Forkez le projet
2. Créez une branche feature
3. Committez vos changements
4. Pushez vers la branche
5. Ouvrez une Pull Request

## 📄 Licence

Ce projet suit les licences individuelles de chaque package. Voir les fichiers `APKBUILD` pour les détails.