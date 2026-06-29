#!/usr/bin/env bash

# Script para limpiar paquetes de manera segura en Arch Linux (y derivados)
# Permite downgrades al conservar las últimas 3 versiones de cada paquete.
# Debe ejecutarse como usuario normal (solicitará sudo cuando sea necesario).

set -euo pipefail

# Colores para la salida
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Iniciando Limpieza Segura de Paquetes ===${NC}"

# 1. Verificar paccache
if ! command -v paccache &>/dev/null; then
    echo -e "${RED}Error: 'paccache' no está instalado.${NC}"
    echo -e "Por favor, instala 'pacman-contrib' con: ${YELLOW}sudo pacman -S pacman-contrib${NC}"
    exit 1
fi

# 2. Limpieza de caché de Pacman (requiere sudo)
echo -e "\n${GREEN}[1/4] Limpiando caché oficial de Pacman (guardando últimas 3 versiones)...${NC}"
sudo paccache -r

# 3. Limpieza de caché de AUR Helpers (Yay / Paru)
# Nota: se ejecuta con el usuario actual para limpiar su propio directorio ~/.cache
clean_aur_cache() {
    local helper_name="$1"
    local cache_dir="$2"
    
    if [ -d "$cache_dir" ]; then
        echo -e "\n${GREEN}[2/4] Buscando caché de $helper_name en $cache_dir...${NC}"
        
        # Buscar directorios que contengan archivos de paquetes (.pkg.tar.*)
        # y aplicar paccache en cada uno de ellos.
        local found=0
        while read -r dir; do
            if [ -n "$dir" ]; then
                echo -e "${BLUE}Limpiando caché en: ${NC}$dir"
                # Se ejecuta sin sudo porque la caché del usuario le pertenece
                paccache -r -c "$dir"
                found=1
            fi
        done < <(find "$cache_dir" -type f -name "*.pkg.tar*" -exec dirname {} + | sort -u)
        
        if [ "$found" -eq 0 ]; then
            echo -e "${YELLOW}No se encontraron paquetes descargados/compilados en la caché de $helper_name.${NC}"
        fi
    else
        echo -e "\n${YELLOW}No se detectó caché para $helper_name en $cache_dir.${NC}"
    fi
}

# Limpiar Yay si existe su carpeta de caché
clean_aur_cache "Yay" "$HOME/.cache/yay"

# Limpiar Paru si existe su carpeta de caché
clean_aur_cache "Paru" "$HOME/.cache/paru"

# 4. Limpiar fuentes y archivos temporales de construcción de AUR (opcional pero muy útil)
# Yay y Paru a menudo guardan carpetas 'src' y 'pkg' de compilaciones pasadas que ocupan gigabytes
clean_aur_sources() {
    local helper_name="$1"
    local cache_dir="$2"
    if [ -d "$cache_dir" ]; then
        echo -e "\n${GREEN}[3/4] Limpiando archivos fuentes/construcción de $helper_name (conservando paquetes)...${NC}"
        # Buscamos carpetas 'src' y 'pkg' dentro de las carpetas de proyectos en cache y las eliminamos
        # Esto no borra los paquetes compilados .pkg.tar.*
        find "$cache_dir" -mindepth 2 -maxdepth 2 -type d \( -name "src" -o -name "pkg" \) -exec rm -rf {} +
        echo -e "${BLUE}Archivos temporales de compilación eliminados.${NC}"
    fi
}

clean_aur_sources "Yay" "$HOME/.cache/yay"
clean_aur_sources "Paru" "$HOME/.cache/paru"

# 5. Eliminar paquetes huérfanos
echo -e "\n${GREEN}[4/4] Comprobando paquetes huérfanos (orphans)...${NC}"
if pacman -Qdtq &>/dev/null; then
    echo -e "${YELLOW}Se encontraron paquetes huérfanos. Eliminando...${NC}"
    sudo pacman -Rns $(pacman -Qdtq)
else
    echo -e "${BLUE}No se encontraron paquetes huérfanos para eliminar.${NC}"
fi

echo -e "\n${GREEN}=== Limpieza finalizada correctamente ===${NC}"
