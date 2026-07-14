#!/bin/bash
set -e

# Colores
BOLD=$(tput bold)
GREEN=$(tput setaf 2)
BLUE=$(tput setaf 4)
YELLOW=$(tput setaf 3)
RED=$(tput setaf 1)
RESET=$(tput sgr0)

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

echo "${BOLD}${BLUE}=== Mantenimiento Automatizado de Arch ===${RESET}"

# 1. Keyring y Dependencias Base (Vital)
echo -e "\n${BOLD}${YELLOW}[1/3] Actualizando Llaves y Base-Devel...${RESET}"
sudo pacman -Sy --noconfirm archlinux-keyring
sudo pacman -S --needed --noconfirm git base-devel

# 2. Flatpak
echo -e "\n${BOLD}${YELLOW}[2/3] Actualizando Flatpaks...${RESET}"
flatpak update -y 

# 3. Paru (Sistema + AUR) - Al final por si requiere interacción prolongada
echo -e "\n${BOLD}${YELLOW}[3/3] Iniciando actualización del Sistema y AUR...${RESET}"

if [ -t 0 ]; then
    # Consola interactiva: Verificamos integridad de paru
    if ! command -v paru &> /dev/null; then
        fix_paru
    fi

    # Notificación al usuario de que se requiere acción en la terminal
    echo -e "${BLUE}🔔 Se requiere interacción en la terminal para revisar y aceptar los cambios...${RESET}"
    notify-send --expire-time=15000 --urgency=normal "Actualización del Sistema" "Paru requiere tu intervención en la terminal para continuar." 2>/dev/null || true
    echo -e "\a" # Sonido de campana

    # Ejecutar paru interactivo (permite revisar diffs y aceptar de forma individual)
    paru -Syu
else
    # Consola no interactiva: evitar actualizaciones del AUR por completo
    echo -e "${YELLOW}⚠️ Consola no interactiva detectada. Evitando actualizaciones del AUR.${RESET}"
    echo -e "Ejecutando actualización únicamente de los repositorios oficiales..."
    sudo pacman -Syu --noconfirm
fi

# Recompilar plugins de Hyprland (hyprpm) después de actualizar el sistema
echo -e "\n${BOLD}${YELLOW}Recompilando plugins de Hyprland...${RESET}"
hyprpm update || true

echo -e "\n${BOLD}${GREEN}✅ Sistema actualizado y limpio.${RESET}"
notify-send --expire-time=7000 "Update Completo" "Arch Linux actualizado y verificado." 2>/dev/null || true

sudo needrestart

