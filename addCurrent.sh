#!/bin/bash

# --- Configuración ---
DOTFILES_DIR="$HOME/dotfiles"

# Comprobar si se pasó un argumento
if [ -z "$1" ]; then
    echo "Uso: $0 <archivo_o_directorio>"
    echo "Ejemplo: $0 ~/.config/kitty"
    exit 1
fi

TARGET=$(realpath "$1")
REL_PATH="${TARGET#$HOME/}"
PACKAGE_NAME=$(echo "$REL_PATH" | cut -d'/' -f1)

# Si el archivo está en .config, el nombre del paquete debería ser el de la app
if [[ "$PACKAGE_NAME" == ".config" ]]; then
    PACKAGE_NAME=$(echo "$REL_PATH" | cut -d'/' -f2)
fi

echo "📦 Procesando: $REL_PATH -> Paquete: $PACKAGE_NAME"

# 1. Crear la estructura de directorios en el repo
DEST_DIR="$DOTFILES_DIR/$PACKAGE_NAME/$(dirname "$REL_PATH")"
mkdir -p "$DEST_DIR"

# 2. Mover el archivo/directorio al repo
if [ -e "$TARGET" ]; then
    mv "$TARGET" "$DEST_DIR/"
    echo "✅ Movido a $DEST_DIR"
else
    echo "❌ Error: El objetivo no existe."
    exit 1
fi

# 3. Ejecutar GNU Stow
cd "$DOTFILES_DIR"
stow "$PACKAGE_NAME"

echo "🔗 Enlace simbólico creado con éxito.#!/bin/bash

# --- Configuración ---
DOTFILES_DIR="$HOME/dotfiles"

# Comprobar si se pasó un argumento
if [ -z "$1" ]; then
    echo "Uso: $0 <archivo_o_directorio>"
    echo "Ejemplo: $0 ~/.config/kitty"
    exit 1
fi

TARGET=$(realpath "$1")
REL_PATH="${TARGET#$HOME/}"
PACKAGE_NAME=$(echo "$REL_PATH" | cut -d'/' -f1)

# Si el archivo está en .config, el nombre del paquete debería ser el de la app
if [[ "$PACKAGE_NAME" == ".config" ]]; then
    PACKAGE_NAME=$(echo "$REL_PATH" | cut -d'/' -f2)
fi

echo "📦 Procesando: $REL_PATH -> Paquete: $PACKAGE_NAME"

# 1. Crear la estructura de directorios en el repo
DEST_DIR="$DOTFILES_DIR/$PACKAGE_NAME/$(dirname "$REL_PATH")"
mkdir -p "$DEST_DIR"

# 2. Mover el archivo/directorio al repo
if [ -e "$TARGET" ]; then
    mv "$TARGET" "$DEST_DIR/"
    echo "✅ Movido a $DEST_DIR"
else
    echo "❌ Error: El objetivo no existe."
    exit 1
fi

# 3. Ejecutar GNU Stow
cd "$DOTFILES_DIR"

# Usar --no-folding si el paquete contiene carpetas que terminan en .d (ej. systemd-user con .service.d)
STOW_OPTS=""
if find "$PACKAGE_NAME" -type d -name "*.d" 2>/dev/null | grep -q .; then
    STOW_OPTS="--no-folding"
fi

stow $STOW_OPTS "$PACKAGE_NAME"

echo "🔗 Enlace simbólico creado con éxito."
