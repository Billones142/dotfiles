#!/bin/bash

# Instala el hook de pacman que avisa qué paquetes del AUR usan la API privada de Qt.
# Requiere privilegios de administrador.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "🔧 Instalando script de comprobación en /usr/local/bin..."
sudo install -Dm755 "$SCRIPT_DIR/bin/qt-private-check" /usr/local/bin/qt-private-check

echo "🔧 Instalando hook de pacman..."
sudo install -Dm644 "$SCRIPT_DIR/hooks/qt-private-api.hook" /etc/pacman.d/hooks/qt-private-api.hook

echo "✅ Instalación completada. Prueba manual: qt-private-check"
