#!/usr/bin/env bash

# Script para comprobar la integridad de todos los paquetes del sistema en Arch Linux.
# Detecta archivos faltantes o alterados, incluyendo los paquetes de AUR (con paru),
# ofrece reinstalarlos/corregirlos al final y vuelve a verificarlos tras la reinstalación.
#
# Los módulos del kernel que DKMS desplaza a /var/lib/dkms/<módulo>/original_module
# (p. ej. v4l2loopback en linux-cachyos) se ignoran: no son corrupción, DKMS los
# sustituye a propósito por su propia versión en updates/dkms/.
#
# Ubicación: ~/.scripts/check-integrity.sh

set -euo pipefail

# Inicializar variables para control de errores y limpieza
temp_results=""
sudo_updater_pid=""

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

# Mantener sudo activo en segundo plano mientras dure el escaneo
start_sudo_keepalive() {
    sudo -v
    while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &
    sudo_updater_pid=$!
}

stop_sudo_keepalive() {
    if [ -n "$sudo_updater_pid" ]; then
        kill "$sudo_updater_pid" 2>/dev/null || true
        sudo_updater_pid=""
    fi
}

# Limpieza y restauración del cursor al salir o interrumpir
cleanup() {
    stop_sudo_keepalive
    [ -n "$temp_results" ] && rm -f "$temp_results" || true
    [ -t 1 ] && tput cnorm || true
}
trap cleanup EXIT INT TERM

# Spinner para mostrar progreso
spinner() {
    local pid=$1
    local delay=0.1
    # shellcheck disable=SC1003  # la barra invertida es un carácter literal del spinner
    local spinstr='|/-\'
    if [ -t 1 ]; then
        tput civis || true
    fi
    while kill -0 "$pid" 2>/dev/null; do
        local temp=${spinstr#?}
        printf " [%c] Analizando paquetes del sistema... " "$spinstr"
        spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\r"
    done
    if [ -t 1 ]; then
        tput cnorm || true
    fi
    printf "                                                \r"
}

# Convierte la salida de paccheck a registros "paquete<TAB>ruta<TAB>motivo".
# Formato de paccheck: "paquete: '/ruta' motivo" o "paquete: mensaje" (sin ruta).
normalize_paccheck() {
    local line pkg msg
    while IFS= read -r line; do
        if [[ "$line" =~ ^([^:[:space:]]+):\ \'(.+)\'\ (.+)$ ]]; then
            printf '%s\t%s\t%s\n' "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}" "${BASH_REMATCH[3]}"
        elif [[ "$line" =~ ^([^:[:space:]]+):\ (.+)$ ]]; then
            # Guardar antes de comparar: otro =~ sobrescribiría BASH_REMATCH
            pkg=${BASH_REMATCH[1]}
            msg=${BASH_REMATCH[2]}
            [[ "$pkg" == "error" || "$pkg" == "warning" ]] || printf '%s\t-\t%s\n' "$pkg" "$msg"
        fi
    done
}

# Convierte la salida de 'pacman -Qk[k]' a registros "paquete<TAB>ruta<TAB>motivo".
# Formato: "warning: paquete: /ruta (motivo)". Las líneas "backup file:" (archivos de
# configuración modificados por el usuario) se descartan a propósito.
normalize_pacman() {
    local line
    while IFS= read -r line; do
        if [[ "$line" =~ ^warning:\ ([^:[:space:]]+):\ (/.*)\ \((.+)\)$ ]]; then
            printf '%s\t%s\t%s\n' "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}" "${BASH_REMATCH[3]}"
        fi
    done
}

# Escanea los paquetes indicados (o todos si no se indica ninguno) y escribe los
# problemas encontrados en el archivo dado, en formato normalizado.
scan_packages() {
    local outfile=$1
    shift
    if [ "$check_type" = "fast" ]; then
        sudo pacman -Qk "$@" 2>&1 | normalize_pacman > "$outfile" || true
    elif [ "$use_paccheck" = true ]; then
        # paccheck sin --backup omite los archivos de configuración modificados por el usuario
        sudo paccheck --quiet --files --md5sum "$@" 2>&1 | normalize_paccheck > "$outfile" || true
    else
        sudo pacman -Qkk "$@" 2>&1 | normalize_pacman > "$outfile" || true
    fi
}

run_scan_with_spinner() {
    local scan_pid
    scan_packages "$@" &
    scan_pid=$!
    spinner "$scan_pid"
    wait "$scan_pid"
}

# Módulos de kernel desplazados por DKMS, indexados como "versión-kernel|nombre-archivo".
# DKMS guarda el original en /var/lib/dkms/<mod>/original_module/<kver>/<arch>/<archivo>.
declare -A dkms_displaced=()
load_dkms_displaced() {
    local backup rel kver
    [ -d /var/lib/dkms ] || return 0
    while IFS= read -r -d '' backup; do
        rel=${backup#*/original_module/}
        kver=${rel%%/*}
        dkms_displaced["$kver|$(basename "$backup")"]=1
    done < <(find /var/lib/dkms -path '*/original_module/*' -type f ! -name '*.origin' -print0 2>/dev/null)
}

# Un archivo faltante es un módulo desplazado por DKMS si DKMS guardó una copia de
# ese mismo módulo para esa misma versión de kernel.
is_dkms_displaced() {
    local path=$1 reason=$2 rel kver
    [[ "$reason" == "missing file" || "$reason" == "No such file or directory" ]] || return 1
    [[ "$path" =~ ^/usr/lib/modules/[^/]+/ ]] || return 1
    rel=${path#/usr/lib/modules/}
    kver=${rel%%/*}
    [ -n "${dkms_displaced["$kver|$(basename "$path")"]+x}" ]
}

# Lee un archivo de resultados y rellena broken_pkgs (únicos, en orden) e
# ignored_files (módulos desplazados por DKMS).
collect_broken() {
    local results=$1 pkg path reason
    declare -gA seen_broken=()
    broken_pkgs=()
    ignored_files=()
    while IFS=$'\t' read -r pkg path reason; do
        [ -z "$pkg" ] && continue
        if is_dkms_displaced "$path" "$reason"; then
            ignored_files+=("$pkg: $path")
            continue
        fi
        if [ -z "${seen_broken["$pkg"]+x}" ]; then
            seen_broken["$pkg"]=1
            broken_pkgs+=("$pkg")
        fi
    done < "$results"
}

print_ignored_files() {
    [ ${#ignored_files[@]} -eq 0 ] && return 0
    echo -e "${BLUE}ℹ Se ignoraron ${#ignored_files[@]} archivo(s) desplazado(s) intencionadamente por DKMS:${NC}"
    local f
    for f in "${ignored_files[@]}"; do
        echo -e "  - $f"
    done
    echo ""
}

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

use_paccheck=false
if [ "$check_type" = "deep" ] && command -v paccheck &>/dev/null; then
    use_paccheck=true
fi

echo ""
echo -e "${CYAN}Preparando el escaneo...${NC}"
if [ "$check_type" = "deep" ]; then
    echo -e "${YELLOW}Nota: El análisis profundo verifica el contenido de los archivos. Puede tardar unos minutos.${NC}"
    if [ "$use_paccheck" = false ]; then
        echo -e "${YELLOW}paccheck (de pacutils) no encontrado. Usando 'pacman -Qkk' como alternativa...${NC}"
    fi
fi

# Solicitar privilegios de sudo antes de iniciar para no interrumpir el spinner
echo -e "${BLUE}Solicitando privilegios de sudo para el análisis...${NC}"
start_sudo_keepalive

temp_results=$(mktemp)
run_scan_with_spinner "$temp_results"
stop_sudo_keepalive

load_dkms_displaced
collect_broken "$temp_results"
print_ignored_files

# Separar paquetes oficiales y de AUR/locales (foreign)
declare -A foreign_pkgs=()
while IFS= read -r f_pkg; do
    foreign_pkgs["$f_pkg"]=1
done < <(pacman -Qmq)

broken_official=()
broken_aur=()
for pkg in "${broken_pkgs[@]}"; do
    if [ -n "${foreign_pkgs["$pkg"]+x}" ]; then
        broken_aur+=("$pkg")
    else
        broken_official+=("$pkg")
    fi
done

total_broken=${#broken_pkgs[@]}

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

# Paquetes que realmente se intentaron reinstalar (los que se verificarán de nuevo)
reinstalled=()

# Reinstalar paquetes de repositorios oficiales
if [ ${#broken_official[@]} -gt 0 ]; then
    echo -e "${BLUE}Reinstalando paquetes oficiales a través de pacman...${NC}"
    # Ejecutamos de manera interactiva para permitir confirmación y ver progreso
    if sudo pacman -S "${broken_official[@]}"; then
        echo -e "${GREEN}Paquetes oficiales reinstalados.${NC}"
        reinstalled+=("${broken_official[@]}")
    else
        echo -e "${RED}Error: pacman no pudo reinstalar los paquetes oficiales.${NC}"
    fi
    echo ""
fi

# Reinstalar paquetes de AUR
if [ ${#broken_aur[@]} -gt 0 ]; then
    if command -v paru &>/dev/null; then
        echo -e "${YELLOW}Reconstruyendo y reinstalando paquetes de AUR con paru...${NC}"
        # Se ejecuta sin sudo porque paru no permite ejecutarse como root
        # Usamos --rebuild para forzar la compilación limpia de los paquetes rotos
        if paru -S --rebuild "${broken_aur[@]}"; then
            echo -e "${GREEN}Paquetes de AUR reinstalados.${NC}"
            reinstalled+=("${broken_aur[@]}")
        else
            echo -e "${RED}Error: paru no pudo reinstalar los paquetes de AUR.${NC}"
        fi
    else
        echo -e "${RED}Advertencia: 'paru' no está instalado o no se encuentra en el PATH.${NC}"
        echo -e "No se pueden reinstalar automáticamente los siguientes paquetes de AUR: ${broken_aur[*]}"
    fi
    echo ""
fi

if [ ${#reinstalled[@]} -eq 0 ]; then
    echo -e "${RED}✖ No se reinstaló ningún paquete. Revisa los errores anteriores.${NC}"
    exit 1
fi

# Verificar de nuevo los paquetes reinstalados. Se recargan los módulos de DKMS
# porque la reinstalación de un kernel puede haber cambiado su estado.
echo -e "${CYAN}=== Verificando de nuevo los paquetes reinstalados ===${NC}"
start_sudo_keepalive
run_scan_with_spinner "$temp_results" "${reinstalled[@]}"
stop_sudo_keepalive

dkms_displaced=()
load_dkms_displaced
collect_broken "$temp_results"
print_ignored_files

failed=$(( total_broken - ${#reinstalled[@]} ))
if [ ${#broken_pkgs[@]} -gt 0 ]; then
    echo -e "${RED}✖ Estos paquetes siguen con problemas tras la reinstalación:${NC}"
    for pkg in "${broken_pkgs[@]}"; do
        echo -e "  - $pkg"
    done
    echo -e "Algo los modifica de forma recurrente (p. ej. DKMS, un hook o un script). Revisa los detalles con:"
    echo -e "  sudo paccheck --files --md5sum ${broken_pkgs[*]}"
    exit 1
fi

echo -e "${GREEN}✔ Los ${#reinstalled[@]} paquete(s) reinstalados pasan ahora la prueba de integridad.${NC}"
if [ "$failed" -gt 0 ]; then
    echo -e "${YELLOW}⚠ $failed paquete(s) no se pudieron reinstalar. Revisa los errores anteriores.${NC}"
    exit 1
fi
echo -e "${GREEN}✔ ¡Proceso de corrección finalizado con éxito!${NC}"
