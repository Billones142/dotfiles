#!/bin/bash
# Configuración de rutas
DOTFILES_DIR="$HOME/dotfiles"
DEST_DIR="$HOME"

# Validar directorio de dotfiles
if [ ! -d "$DOTFILES_DIR" ]; then
    echo "Error: No se encontró el directorio $DOTFILES_DIR"
    exit 1
fi

# Arrays para organizar el reporte final
PENDIENTES=()
DETALLES_PENDIENTES=""

echo "--- Verificando estado de Stow en $DEST_DIR ---"

# Entramos temporalmente para listar las carpetas
cd "$DOTFILES_DIR" || exit

for dir in */; do
    package=${dir%/}
    
    # Ejecutamos simulación con doble verbose para el análisis
    output=$(stow -nvv -d "$DOTFILES_DIR" -t "$DEST_DIR" "$package" 2>&1)
    
    # Contamos estados
    has_links=$(echo "$output" | grep -c "LINK")
    has_skips=$(echo "$output" | grep -E -c "Skipping|UP TO DATE")
    has_errors=$(echo "$output" | grep -c "EXISTING")

    if [ "$has_errors" -gt 0 ]; then
        echo "⚠ [!] CONFLICTO: $package"
    elif [ "$has_links" -gt 0 ] && [ "$has_skips" -gt 0 ]; then
        echo "◍ [/-] INCOMPLETO: $package"
        PENDIENTES+=("$package")
        # Extraer solo las líneas de archivos que faltan por enlazar
        archivos_faltantes=$(echo "$output" | grep "LINK" | sed 's/^LINK: //')
        DETALLES_PENDIENTES+="\n--- Detalles para $package ---\n$archivos_faltantes\n"
    elif [ "$has_links" -gt 0 ]; then
        echo "✘ [ ] NO APLICADO: $package"
        PENDIENTES+=("$package")
    else
        echo "✔ [x] APLICADO: $package"
    fi
done

# --- SECCIÓN FINAL DE DETALLES Y COMANDOS ---
if [ ${#PENDIENTES[@]} -ne 0 ]; then
    echo -e "\n=========================================="
    echo "   RESUMEN DE ACCIONES PENDIENTES"
    echo -e "==========================================\n"
    
    echo -e "Archivos específicos no enlazados:$DETALLES_PENDIENTES"
    
    echo -e "\nComandos para aplicar (puedes ejecutarlos desde cualquier ruta):"
    for pkg in "${PENDIENTES[@]}"; do
        # El comando incluye -d y -t para ser independiente del CWD 
        echo "stow -d $DOTFILES_DIR -t $DEST_DIR $pkg"
    done
else
    echo -e "\n✔ Todo está correctamente aplicado."
fi
