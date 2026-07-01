#!/usr/bin/env bash

# Script para comprobar la integridad de todos los paquetes del sistema en Arch Linux.
# Detecta archivos faltantes o alterados, incluyendo los paquetes de AUR (con paru),
# y ofrece reinstalarlos/corregirlos al final.
#
# Ubicación: ~/.scripts/check-integrity.sh

set -euo pipefail

# Inicializar variables para control de errores y limpieza
temp_broken=""

# Colores para la salida
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # Sin color

# Verificar que no se ejecute como root/sudo directamente
if [ "$EUID" -eq 0 ]; then
    echo -e "${RED}Error: No ejecutes este script como root o con sudo.${NC}"
    echo -e "El script solicitará privilegios de administrador (sudo) solo cuando sea necesario,"
    echo -e "pero debe iniciarse como usuario normal para que 'paru' funcione correctamente al reconstruir paquetes de AUR.${NC}"
    exit 1
fi

# Verificar que pacman esté instalado
if ! command -v pacman &>/dev/null; then
    echo -e "${RED}Error: 'pacman' no está instalado. Este script requiere un sistema basado en Arch Linux.${NC}"
    exit 1
fi

# Limpieza y restauración del cursor al salir o interrumpir
cleanup() {
    [ -n "$temp_broken" ] && rm -f "$temp_broken" || true
    [ -t 1 ] && tput cnorm || true
}
trap cleanup EXIT INT TERM

# Encabezado
echo -e "${BLUE}==================================================${NC}"
echo -e "${BLUE}      Comprobador de Integridad de Paquetes       ${NC}"
echo -e "${BLUE}==================================================${NC}"
echo ""

# Menú de selección
echo -e "Selecciona el tipo de análisis:"
echo -e "  ${GREEN}1)${NC} ${BOLD}Análisis Rápido${NC} (Verifica solo archivos faltantes con 'pacman -Qk'. Rápido y seguro)"
echo -e "  ${GREEN}2)${NC} ${BOLD}Análisis Profundo${NC} (Verifica integridad y md5sums. Usa 'paccheck' o 'pacman -Qkk')"
echo -e "  ${GREEN}3)${NC} Salir"
echo ""
read -rp "Seleccione una opción [1-3]: " choice || choice=3

case "$choice" in
    1)
        check_type="fast"
        ;;
    2)
        check_type="deep"
        ;;
    3|*)
        echo -e "${BLUE}Saliendo del comprobador. ¡Buen día!${NC}"
        exit 0
        ;;
esac

echo ""
echo -e "${CYAN}Preparando el escaneo...${NC}"
if [ "$check_type" = "deep" ]; then
    echo -e "${YELLOW}Nota: El análisis profundo verifica el contenido de los archivos. Puede tardar unos minutos.${NC}"
fi

# Solicitar privilegios de sudo antes de iniciar para no interrumpir el spinner
echo -e "${BLUE}Solicitando privilegios de sudo para el análisis...${NC}"
sudo -v

# Mantener sudo activo en segundo plano mientras dure el escaneo
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &
sudo_updater_pid=$!

# Spinner para mostrar progreso
spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='|/-\'
    if [ -t 1 ]; then
        tput civis
    fi
    while [ "$(ps a | awk '{print $1}' | grep -w "$pid")" ]; do
        local temp=${spinstr#?}
        printf " [%c] Analizando paquetes del sistema... " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\r"
    done
    if [ -t 1 ]; then
        tput cnorm
    fi
    printf "                                                \r"
}

# Archivo temporal para los resultados del escaneo
temp_broken=$(mktemp)

# Ejecutar el escaneo según la selección
if [ "$check_type" = "fast" ]; then
    (
        sudo pacman -Qk 2>/dev/null | grep -v '0 missing files' > "$temp_broken" || true
    ) &
    scan_pid=$!
    spinner "$scan_pid"
    wait "$scan_pid"
else
    # Análisis profundo
    if command -v paccheck &>/dev/null; then
        (
            # paccheck sin --backup omite los archivos de configuración modificados por el usuario
            sudo paccheck --list-broken --files --md5sum > "$temp_broken" 2>/dev/null || true
        ) &
        scan_pid=$!
        spinner "$scan_pid"
        wait "$scan_pid"
    else
        echo -e "${YELLOW}paccheck (de pacutils) no encontrado. Usando 'pacman -Qkk' como alternativa...${NC}"
        (
            sudo pacman -Qkk 2>/dev/null | grep -v '0 altered files' > "$temp_broken" || true
        ) &
        scan_pid=$!
        spinner "$scan_pid"
        wait "$scan_pid"
    fi
fi

# Detener el actualizador de sudo
kill "$sudo_updater_pid" 2>/dev/null || true

# Listas para guardar los paquetes rotos
broken_official=()
broken_aur=()

# Obtener lista de todos los paquetes de AUR/locales (foreign)
mapfile -t foreign_pkgs < <(pacman -Qmq)

# Función para verificar si un paquete es de AUR
is_foreign() {
    local pkg=$1
    for f_pkg in "${foreign_pkgs[@]}"; do
        if [ "$f_pkg" = "$pkg" ]; then
            return 0
        fi
    done
    return 1
}

# Procesar el archivo de resultados
if [ -s "$temp_broken" ]; then
    while read -r line; do
        [ -z "$line" ] && continue
        
        local pkg=""
        
        # El formato de pacman es "nombre-paquete: X total files, Y missing/altered files"
        # El formato de paccheck es simplemente "nombre-paquete"
        if [[ "$line" =~ ^([^:]+): ]]; then
            pkg="${BASH_REMATCH[1]}"
        else
            pkg="$line"
        fi
        
        # Limpiar espacios
        pkg=$(echo "$pkg" | xargs)
        
        # Evitar duplicados en las listas
        if [[ " ${broken_official[*]} " =~ " ${pkg} " ]] || [[ " ${broken_aur[*]} " =~ " ${pkg} " ]]; then
            continue
        fi
        
        if is_foreign "$pkg"; then
            broken_aur+=("$pkg")
        else
            broken_official+=("$pkg")
        fi
    done < "$temp_broken"
fi

total_broken=$(( ${#broken_official[@]} + ${#broken_aur[@]} ))

if [ "$total_broken" -eq 0 ]; then
    echo -e "${GREEN}✔ ¡Todos los paquetes pasaron la prueba de integridad! No se encontraron problemas.${NC}"
    exit 0
fi

# Mostrar paquetes rotos
echo -e "${RED}✖ Se encontraron $total_broken paquete(s) con problemas de integridad:${NC}"
echo ""

if [ ${#broken_official[@]} -gt 0 ]; then
    echo -e "${CYAN}[Repositorios Oficiales]${NC}"
    for pkg in "${broken_official[@]}"; do
        echo -e "  - $pkg"
    done
    echo ""
fi

if [ ${#broken_aur[@]} -gt 0 ]; then
    echo -e "${YELLOW}[AUR (Paquetes Externos)]${NC}"
    for pkg in "${broken_aur[@]}"; do
        echo -e "  - $pkg"
    done
    echo ""
fi

# Preguntar si se desean corregir
read -rp "¿Deseas reinstalar y corregir estos paquetes? [s/N]: " confirm || confirm="n"
if [[ ! "$confirm" =~ ^[sS]([iI])?$ ]]; then
    echo -e "${BLUE}Operación cancelada. No se modificó ningún paquete.${NC}"
    exit 0
fi

echo ""
echo -e "${CYAN}=== Iniciando Reinstalación de Paquetes ===${NC}"
echo ""

# Reinstalar paquetes de repositorios oficiales
if [ ${#broken_official[@]} -gt 0 ]; then
    echo -e "${BLUE}Reinstalando paquetes oficiales a través de pacman...${NC}"
    # Ejecutamos de manera interactiva para permitir confirmación y ver progreso
    sudo pacman -S "${broken_official[@]}"
    echo -e "${GREEN}Paquetes oficiales reinstalados.${NC}"
    echo ""
fi

# Reinstalar paquetes de AUR
if [ ${#broken_aur[@]} -gt 0 ]; then
    if command -v paru &>/dev/null; then
        echo -e "${YELLOW}Reconstruyendo y reinstalando paquetes de AUR con paru...${NC}"
        # Se ejecuta sin sudo porque paru no permite ejecutarse como root
        # Usamos --rebuild para forzar la compilación limpia de los paquetes rotos
        paru -S --rebuild "${broken_aur[@]}"
        echo -e "${GREEN}Paquetes de AUR reinstalados.${NC}"
    else
        echo -e "${RED}Advertencia: 'paru' no está instalado o no se encuentra en el PATH.${NC}"
        echo -e "No se pueden reinstalar automáticamente los siguientes paquetes de AUR: ${broken_aur[*]}"
    fi
    echo ""
fi

echo -e "${GREEN}✔ ¡Proceso de corrección finalizado con éxito!${NC}"
