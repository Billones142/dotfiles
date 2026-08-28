#!/bin/bash
set -e

# Colores
BOLD=$(tput bold)
GREEN=$(tput setaf 2)
BLUE=$(tput setaf 4)
YELLOW=$(tput setaf 3)
RED=$(tput setaf 1)
RESET=$(tput sgr0)

function usage() {
    cat <<EOF
Uso: ${0##*/} [opciones]

Opciones:
  -n, --dry-run   Solo lista las actualizaciones disponibles, sin instalar nada.
  -h, --help      Muestra esta ayuda.
EOF
}

# --- REPORTE DE ACTUALIZACIONES PENDIENTES (dry-run) ---
# Imprime la lista de una sección con su subtotal y deja el conteo en SECTION_COUNT.
function print_section() {
    local updates="$1"
    SECTION_COUNT=0
    if [ -n "$updates" ]; then
        echo "$updates"
        SECTION_COUNT=$(wc -l <<< "$updates")
    else
        echo "Sin actualizaciones."
    fi
    echo -e "${BOLD}Subtotal: ${SECTION_COUNT} paquete(s)${RESET}"
}

# Solo consulta; no requiere sudo ni modifica la base de datos de pacman.
function dry_run_report() {
    local total=0

    echo "${BOLD}${BLUE}=== Actualizaciones disponibles (dry-run) ===${RESET}"

    # Repos oficiales: checkupdates (pacman-contrib) sincroniza en una db temporal.
    echo -e "\n${BOLD}${YELLOW}[1/3] Repositorios oficiales...${RESET}"
    if command -v checkupdates &> /dev/null; then
        # checkupdates devuelve 2 cuando no hay actualizaciones: no es un error.
        print_section "$(checkupdates 2>/dev/null || true)"
        total=$((total + SECTION_COUNT))
    else
        echo -e "${YELLOW}⚠️ 'checkupdates' no disponible. Instalar con: sudo pacman -S pacman-contrib${RESET}"
    fi

    # AUR: paru -Qua consulta sin tocar el sistema.
    echo -e "\n${BOLD}${YELLOW}[2/3] AUR...${RESET}"
    if command -v paru &> /dev/null; then
        print_section "$(paru -Qua 2>/dev/null || true)"
        total=$((total + SECTION_COUNT))
    else
        echo -e "${YELLOW}⚠️ 'paru' no instalado. Se reconstruiría al ejecutar sin --dry-run.${RESET}"
    fi

    # Flatpak
    echo -e "\n${BOLD}${YELLOW}[3/3] Flatpak...${RESET}"
    if command -v flatpak &> /dev/null; then
        print_section "$(flatpak remote-ls --updates --columns=application,version 2>/dev/null || true)"
        total=$((total + SECTION_COUNT))
    else
        echo -e "${YELLOW}⚠️ 'flatpak' no instalado.${RESET}"
    fi

    echo -e "\n${BOLD}${GREEN}Total de paquetes con actualización: ${total}${RESET}"
    echo -e "${BLUE}Nada fue modificado (dry-run).${RESET}"
}

DRY_RUN=false
for arg in "$@"; do
    case "$arg" in
        -n|--dry-run) DRY_RUN=true ;;
        -h|--help) usage; exit 0 ;;
        *)
            echo -e "${RED}Opción desconocida: $arg${RESET}" >&2
            usage >&2
            exit 1
            ;;
    esac
done

if [ "$DRY_RUN" = true ]; then
    dry_run_report
    exit 0
fi

# pide los permisos de sudo
sudo -v

# Mantener el sudo "vivo" en segundo plano de forma robusta
# Usamos un bucle infinito simple que solo refresca el token cada 60 segundos.
# Al usar 'disown', lo separamos completamente del flujo de procesos de yay/makepkg.
while true; do 
    sudo -n true 2>/dev/null
    sleep 60
done &
SUDO_KEEP_ALIVE_PID=$!

# Asegurar que el bucle muera SÍ O SÍ cuando el script termine (con éxito o por error)
trap "kill $SUDO_KEEP_ALIVE_PID 2>/dev/null" EXIT

# --- FUNCIÓN DE AUTOREPARACIÓN ---
function fix_paru() {
    echo -e "${RED}⚠️  Detectado fallo en PARU. Iniciando protocolo de reparación...${RESET}"
    
    # 1. Asegurar herramientas de compilación
    sudo pacman -S --needed --noconfirm git base-devel
    
    # 2. Limpieza de versiones conflictivas previas
    sudo pacman -Rns --noconfirm paru paru-git paru-bin 2>/dev/null || true
    
    # 3. Preparar entorno limpio en /tmp (RAM)
    WORK_DIR=$(mktemp -d)
    echo "🔧 Clonando paru-bin en $WORK_DIR..."
    git clone https://aur.archlinux.org/paru-bin.git "$WORK_DIR/paru-bin"
    
    # 4. Compilar e instalar
    cd "$WORK_DIR/paru-bin"
    echo "🔨 Compilando paru-bin..."
    makepkg -si --noconfirm
    
    # 5. Limpieza
    cd ~
    rm -rf "$WORK_DIR"
    echo -e "${GREEN}✅ PARU ha sido reconstruido exitosamente.${RESET}"
}

# --- SNAPSHOTS DE RESTAURACION ---
SNAPPER_CONFIG="root"
SNAPSHOT_DESC="update_all"
MAX_SNAPSHOTS=3

# Devuelve los numeros de snapshot de este script, del mas viejo al mas nuevo.
function list_own_snapshots() {
    sudo snapper -c "$SNAPPER_CONFIG" list --columns number,description 2>/dev/null |
        awk -F'|' -v desc="$SNAPSHOT_DESC" '
            NR > 2 {
                num = $1; dsc = $2
                gsub(/^[ \t]+|[ \t]+$/, "", num)
                gsub(/^[ \t]+|[ \t]+$/, "", dsc)
                if (dsc == desc && num ~ /^[0-9]+$/) print num
            }'
}

# Borra los snapshots mas viejos para que, tras crear el nuevo, queden MAX_SNAPSHOTS.
function prune_snapshots() {
    local snaps sobrantes
    mapfile -t snaps < <(list_own_snapshots)

    sobrantes=$(( ${#snaps[@]} - (MAX_SNAPSHOTS - 1) ))
    if [ "$sobrantes" -le 0 ]; then
        return 0
    fi

    local a_borrar=("${snaps[@]:0:$sobrantes}")
    echo "🧹 Borrando snapshots antiguos de '$SNAPSHOT_DESC': ${a_borrar[*]}"
    sudo snapper -c "$SNAPPER_CONFIG" delete "${a_borrar[@]}" ||
        echo -e "${YELLOW}⚠️ No se pudieron borrar snapshots antiguos.${RESET}"
}

# Crea el snapshot previo a la actualizacion. Si falla, aborta el script.
function create_snapshot() {
    local num
    if ! num=$(sudo snapper -c "$SNAPPER_CONFIG" create --type single --print-number \
                    --description "$SNAPSHOT_DESC" 2>&1); then
        echo -e "${RED}❌ Error creando el snapshot: ${num}${RESET}" >&2
        exit 1
    fi
    echo -e "${GREEN}📸 Snapshot #${num} creado ('${SNAPSHOT_DESC}').${RESET}"
}

if ! command -v snapper &> /dev/null; then
    echo -e "${RED}❌ 'snapper' no está instalado; no se puede crear el punto de restauración.${RESET}" >&2
    exit 1
fi

echo "${BOLD}${BLUE}=== Mantenimiento Automatizado de Arch ===${RESET}"

# Punto de restauracion (snapper). Solo gestiona snapshots propios de este script,
# identificados por su descripcion; los de snap-pac quedan intactos.
echo -e "\n${BOLD}${YELLOW}[0/3] Creando punto de restauración...${RESET}"
prune_snapshots
create_snapshot

# 1. Keyring y Dependencias Base (Vital)
echo -e "\n${BOLD}${YELLOW}[1/3] Actualizando Llaves y Base-Devel...${RESET}"
sudo pacman -Sy --noconfirm archlinux-keyring
sudo pacman -S --needed --noconfirm git base-devel

# 2. Flatpak
echo -e "\n${BOLD}${YELLOW}[2/3] Actualizando Flatpaks...${RESET}"
flatpak update -y 

# 3. Paru (Sistema + AUR)
echo -e "\n${BOLD}${YELLOW}[3/3] Iniciando actualización del Sistema y AUR...${RESET}"

if [ -t 0 ]; then
    # Consola interactiva: Verificamos integridad de paru
    if ! command -v paru &> /dev/null; then
        fix_paru
    fi

    # actualizar paquetes del sistema
    sudo pacman -Syu --noconfirm

    # Notificación al usuario de que se requiere acción en la terminal
    echo -e "${BLUE}🔔 Se requiere interacción en la terminal para revisar y aceptar los cambios...${RESET}"
    notify-send --expire-time=15000 --urgency=normal "Actualización del Sistema" "Paru requiere tu intervención en la terminal para continuar." 2>/dev/null || true
    echo -e "\a" # Sonido de campana


    # Ejecutar paru interactivo (permite revisar diffs y aceptar de forma individual)
    paru -Syau
else
    # Consola no interactiva: evitar actualizaciones del AUR por completo
    echo -e "${YELLOW}⚠️ Consola no interactiva detectada. Evitando actualizaciones del AUR.${RESET}"
    echo -e "Ejecutando actualización únicamente de los repositorios oficiales..."
    sudo pacman -Syu --noconfirm
fi

# Reiniciar servicios obsoletos (needrestart) mientras la caché de sudo sigue activa
sudo needrestart

# Recompilar plugins de Hyprland (hyprpm) al final del todo.
# Como hyprpm puede invalidar la caché de sudo, lo ejecutamos al final para no afectar otros comandos.
echo -e "\n${BOLD}${YELLOW}Recompilando plugins de Hyprland...${RESET}"
hyprpm update || true

echo -e "\n${BOLD}${GREEN}✅ Sistema actualizado y limpio.${RESET}"
notify-send --expire-time=7000 "Update Completo" "Arch Linux actualizado y verificado." 2>/dev/null || true



