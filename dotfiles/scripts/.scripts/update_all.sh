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

# Mantener el sudo "vivo" en segundo plano
# Esto corre un bucle que actualiza el timeout cada 60 segundos
# hasta que el script principal termine.
( while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null & )

# --- FUNCIÓN DE AUTOREPARACIÓN ---
function fix_yay() {
    echo -e "${RED}⚠️  Detectado fallo en YAY. Iniciando protocolo de reparación...${RESET}"
    
    # 1. Asegurar herramientas de compilación (usando pacman, que es seguro)
    sudo pacman -S --needed --noconfirm git base-devel
    
    # 2. Limpieza de versiones conflictivas previas
    # Eliminamos yay, yay-git, o versiones debug para evitar conflictos de archivos
    sudo pacman -Rns --noconfirm yay yay-git yay-bin yay-debug yay-git-debug 2>/dev/null || true
    
    # 3. Preparar entorno limpio en /tmp (RAM)
    WORK_DIR=$(mktemp -d)
    echo "🔧 Clonando yay en $WORK_DIR..."
    git clone https://aur.archlinux.org/yay.git "$WORK_DIR/yay"
    
    # 4. Compilar e instalar
    cd "$WORK_DIR/yay"
    echo "🔨 Compilando yay..."
    makepkg -si --noconfirm
    
    # 5. Limpieza
    cd ~
    rm -rf "$WORK_DIR"
    echo -e "${GREEN}✅ YAY ha sido reconstruido exitosamente.${RESET}"
}

echo "${BOLD}${BLUE}=== Mantenimiento Automatizado de Arch (Self-Healing) ===${RESET}"

# 1. Keyring y Dependencias Base (Vital)
echo -e "\n${BOLD}${YELLOW}[1/4] Actualizando Llaves y Base-Devel...${RESET}"
sudo pacman -Sy --noconfirm archlinux-keyring
# Aseguramos que git y base-devel estén al día por si hay que compilar
sudo pacman -S --needed --noconfirm git base-devel

# 2. Health Check de Yay
echo -e "\n${BOLD}${YELLOW}[2/4] Verificando integridad de Yay...${RESET}"
if ! yay --version > /dev/null 2>&1; then
    # Si el comando falla (exit code != 0), ejecutamos la reparación
    fix_yay
else
    echo "👌 Yay está operativo."
fi

# 3. Yay (Sistema + AUR) - Ahora seguro
echo -e "\n${BOLD}${YELLOW}[3/4] Actualizando Sistema y AUR (Clean Build)...${RESET}"
# --answerclean All: Borra caché de compilación (más estable)
# --answerdiff None: No muestra cambios en el código
# --noconfirm: No pregunta "¿Continuar?" ni muestra menú de exclusión
GODEBUG=netdns=go yay -Syu --noconfirm --answerclean All --answerdiff None

# 4. Flatpak
echo -e "\n${BOLD}${YELLOW}[4/4] Actualizando Flatpaks...${RESET}"
flatpak update -y 

echo -e "\n${BOLD}${GREEN}✅ Sistema actualizado y limpio.${RESET}"
notify-send --expire-time=7000 "Update Completo" "Arch Linux actualizado y verificado." 2>/dev/null || true
sudo needrestart
