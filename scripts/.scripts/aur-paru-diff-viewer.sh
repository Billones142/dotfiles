#!/bin/bash

# Directorio de salida para los diffs
OUTPUT_DIR="${1:-$HOME/aur-diffs}"
PARU_CACHE="$HOME/.cache/paru/clone"

OLD_DIR=$PWD

# Crear directorio si no existe
mkdir -p "$OUTPUT_DIR"
cd $OUTPUT_DIR

# Obtener lista de paquetes con actualizaciones pendientes
updates=$(paru -Quaq)

if [ -z "$updates" ]; then
    echo "No hay actualizaciones pendientes del AUR."
    exit 0
fi

echo "Procesando actualizaciones..."

for pkg in $updates; do
    # 1. Asegurar que tenemos el repositorio clonado en caché
    paru -G "$pkg" --noconfirm > /dev/null 2>&1
    
    cd "$PARU_CACHE/$pkg" || continue
    
    # 2. Generar el diff contra el HEAD anterior
    # Si no hay repositorio git (primera vez), capturamos el PKGBUILD completo
    if [ -d ".git" ]; then
        git diff HEAD^ HEAD PKGBUILD > "$OUTPUT_DIR/${pkg}_diff.txt"
    else
        cat PKGBUILD > "$OUTPUT_DIR/${pkg}_PKGBUILD_full.txt"
    fi
    
    # 3. Eliminar archivo si está vacío (no hubo cambios reales)
    if [ ! -s "$OUTPUT_DIR/${pkg}_diff.txt" ]; then
        rm -f "$OUTPUT_DIR/${pkg}_diff.txt"
    else
        echo "✅ Cambios encontrados para $pkg -> Guardados en $OUTPUT_DIR/${pkg}_diff.txt"
    fi
done

echo "Revisión finalizada. Archivos generados en: $OUTPUT_DIR"
cd $OLD_DIR
