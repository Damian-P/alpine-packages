#!/bin/bash

# Script pour générer la page index.html avec les packages disponibles
# Usage: generate-index.sh <public_dir>

set -e

PUBLIC_DIR=${1:-public}

if [ ! -d "$PUBLIC_DIR" ]; then
    echo "Error: Directory $PUBLIC_DIR does not exist"
    exit 1
fi

echo "Generating index.html in $PUBLIC_DIR"

# Générer la page HTML avec les packages actuels
cat > "$PUBLIC_DIR/index.html" << 'EOF'
<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Alpine Linux Packages</title>
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
            max-width: 800px;
            margin: 0 auto;
            padding: 2rem;
            line-height: 1.6;
            color: #333;
        }
        .header {
            text-align: center;
            margin-bottom: 2rem;
            padding: 2rem;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            border-radius: 10px;
        }
        .arch-section {
            margin: 2rem 0;
            padding: 1.5rem;
            border: 1px solid #ddd;
            border-radius: 8px;
            background-color: #f9f9f9;
        }
        .arch-title {
            color: #4a5568;
            margin-bottom: 1rem;
            font-size: 1.2rem;
            font-weight: bold;
        }
        .package-list {
            list-style: none;
            padding: 0;
        }
        .package-item {
            margin: 0.5rem 0;
            padding: 1rem;
            background: white;
            border-left: 4px solid #667eea;
            border-radius: 4px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        .package-link {
            color: #2d3748;
            text-decoration: none;
            font-family: 'SFMono-Regular', monospace;
            font-size: 0.9rem;
        }
        .package-link:hover {
            color: #667eea;
        }
        .setup-section {
            margin-top: 2rem;
            padding: 1.5rem;
            background-color: #e2e8f0;
            border-radius: 8px;
        }
        pre {
            background: #2d3748;
            color: #e2e8f0;
            padding: 1rem;
            border-radius: 6px;
            overflow-x: auto;
            font-size: 0.85rem;
        }
        .key-info {
            margin-top: 1rem;
            padding: 1rem;
            background-color: #fef5e7;
            border-left: 4px solid #f6ad55;
            border-radius: 4px;
        }
        .package-info {
            display: flex;
            justify-content: space-between;
            align-items: center;
        }
        .package-size {
            color: #718096;
            font-size: 0.8rem;
            font-family: 'SFMono-Regular', monospace;
        }
    </style>
</head>
<body>
    <div class="header">
        <h1>🏔️ Alpine Linux Packages</h1>
        <p>Repository de packages Alpine Linux construits automatiquement</p>
        <p>✅ Repository fonctionnel • 🔐 Index signé • 🔄 Builds automatiques</p>
    </div>

    <div id="packages-container">
EOF

# Générer la liste des packages dynamiquement
total_packages=0
for arch in x86_64 aarch64; do
    if [ -d "$PUBLIC_DIR/main/${arch}" ] && [ -n "$(ls $PUBLIC_DIR/main/${arch}/*.apk 2>/dev/null)" ]; then
        count=$(ls $PUBLIC_DIR/main/${arch}/*.apk 2>/dev/null | wc -l)
        total_packages=$((total_packages + count))
        archEmoji="🖥️"
        if [ "$arch" = "aarch64" ]; then archEmoji="📱"; fi
        
        echo "        <div class=\"arch-section\">" >> "$PUBLIC_DIR/index.html"
        echo "            <h2 class=\"arch-title\">${archEmoji} ${arch} Packages ($count)</h2>" >> "$PUBLIC_DIR/index.html"
        echo "            <ul class=\"package-list\">" >> "$PUBLIC_DIR/index.html"
        
        # Lister et trier les packages
        for apk in $PUBLIC_DIR/main/${arch}/*.apk; do
            if [ -f "$apk" ]; then
                filename=$(basename "$apk")
                name=$(echo "$filename" | sed 's/-[0-9].*//')
                version=$(echo "$filename" | sed -n 's/.*-\([0-9][^-]*-r[0-9]*\)\.apk$/\1/p')
                size=$(stat -f%z "$apk" 2>/dev/null || stat -c%s "$apk" 2>/dev/null || echo "0")
                
                # Formatter la taille
                if [ "$size" -gt $((1024*1024)) ]; then
                    size_formatted="$(( size / 1024 / 1024 )) MB"
                elif [ "$size" -gt 1024 ]; then
                    size_formatted="$(( size / 1024 )) KB"
                else
                    size_formatted="${size} B"
                fi
                
                echo "                <li class=\"package-item\">" >> "$PUBLIC_DIR/index.html"
                echo "                    <div class=\"package-info\">" >> "$PUBLIC_DIR/index.html"
                echo "                        <div>" >> "$PUBLIC_DIR/index.html"
                echo "                            <a href=\"main/${arch}/${filename}\" class=\"package-link\">${name}</a>" >> "$PUBLIC_DIR/index.html"
                echo "                            <div style=\"font-size: 0.8rem; color: #718096; margin-top: 0.2rem;\">" >> "$PUBLIC_DIR/index.html"
                echo "                                Version: ${version}" >> "$PUBLIC_DIR/index.html"
                echo "                            </div>" >> "$PUBLIC_DIR/index.html"
                echo "                        </div>" >> "$PUBLIC_DIR/index.html"
                echo "                        <span class=\"package-size\">${size_formatted}</span>" >> "$PUBLIC_DIR/index.html"
                echo "                    </div>" >> "$PUBLIC_DIR/index.html"
                echo "                </li>" >> "$PUBLIC_DIR/index.html"
            fi
        done
        
        echo "            </ul>" >> "$PUBLIC_DIR/index.html"
        echo "        </div>" >> "$PUBLIC_DIR/index.html"
    fi
done

if [ "$total_packages" -eq 0 ]; then
    echo "        <div style=\"text-align: center; padding: 2rem; color: #718096;\">ℹ️ Aucun package disponible pour le moment.</div>" >> "$PUBLIC_DIR/index.html"
fi

# Terminer la page HTML
cat >> "$PUBLIC_DIR/index.html" << 'EOF'
    </div>

    <div class="setup-section">
        <h2>🔧 Configuration</h2>
        <p>Pour utiliser ce repository avec Alpine Linux :</p>
        
        <div class="key-info">
            <strong>1. Télécharger et installer la clé publique :</strong>
        </div>
        <pre>wget https://damian-p.github.io/alpine-packages/alpine.pub -O /etc/apk/keys/alpine.rsa.pub</pre>

        <div class="key-info">
            <strong>2. Ajouter le repository à votre configuration APK :</strong>
        </div>
        <pre>echo "https://damian-p.github.io/alpine-packages/main" >> /etc/apk/repositories</pre>

        <div class="key-info">
            <strong>3. Mettre à jour l'index des packages :</strong>
        </div>
        <pre>apk update</pre>

        <div class="key-info">
            <strong>4. Rechercher et installer des packages :</strong>
        </div>
        <pre># Rechercher des packages Incus
apk search incus-next
apk search incus-ui

# Installer un package
apk add incus-next</pre>
    </div>

    <div class="key-info">
        <h3>📦 Packages disponibles</h3>
        <ul style="list-style: none; padding: 0; margin: 1rem 0;">
            <li style="margin: 0.5rem 0;">• <strong>incus-next</strong> - Version développement d'Incus (conteneurs et VMs)</li>
            <li style="margin: 0.5rem 0;">• <strong>incus-feature</strong> - Version feature d'Incus avec fonctionnalités expérimentales</li>
            <li style="margin: 0.5rem 0;">• <strong>incus-ui</strong> - Interface web pour Incus</li>
            <li style="margin: 0.5rem 0;">• <strong>hello-test</strong> - Package de test simple</li>
        </ul>
        
        <h3>🔑 Clé publique</h3>
        <p>Clé publique de signature des packages : <a href="alpine.pub">alpine.pub</a></p>
        <p><em>⚠️ Important : Installer la clé avec le nom <code>alpine.rsa.pub</code> pour la validation des signatures</em></p>
    </div>

    <footer style="text-align: center; margin-top: 2rem; color: #718096; font-size: 0.9rem;">
        <p>Construit automatiquement avec GitHub Actions • <a href="https://github.com/Damian-P/alpine-packages" style="color: #667eea;">Source sur GitHub</a></p>
    </footer>
</body>
</html>
EOF

echo "Generated index.html with $total_packages packages"
