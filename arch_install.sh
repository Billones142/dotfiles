#!/bin/bash

# pide los permisos de sudo
sudo -v

# Mantener el sudo "vivo" en segundo plano
# Esto corre un bucle que actualiza el timeout cada 60 segundos
# hasta que el script principal termine.
( while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null & )

sudo pacman -Sy --noconfirm archlinux-keyring
sudo pacman -Syu --noconfirm

sudo pacman -S --needed --noconfirm base-devel git
git config --global core.pager 'moor'
git config --global color.ui auto

# --- Selección de Componentes ---
INSTALL_GUI=false
INSTALL_GAMES=false

read -p "¿Desea instalar el entorno gráfico (GUI)? [S/n]: " response_gui
response_gui=${response_gui:-S}
if [[ "$response_gui" =~ ^[SsYy]$ ]]; then
    INSTALL_GUI=true
    read -p "¿Desea instalar los paquetes de juegos (Steam, Lutris, MangoHud, etc.)? [S/n]: " response_games
    response_games=${response_games:-S}
    if [[ "$response_games" =~ ^[SsYy]$ ]]; then
        INSTALL_GAMES=true
    fi
fi

# --- Definición de Paquetes ---

PACKAGES_BASE=(
    nmap
    flatpak
    firewalld
    stow
    tailscale
    htop
    nvtop
    wget
    python-reportlab
    moor
    less
    fuse2
    github-cli
    syncthing
    arj
    lrzip
    lzop
    7zip
    unarchiver
    unrar
    docker
)

# --- Detección de Hardware ---
DETECT_NVIDIA=false
DETECT_AMD=false
DETECT_INTEL=false
DETECT_BLUETOOTH=false
DETECT_BATTERY=false

# 1. Gráfica
gpu_info=$(lspci | grep -iE "vga|3d|3d controller|display")
if echo "$gpu_info" | grep -iq "nvidia"; then
    DETECT_NVIDIA=true
fi
if echo "$gpu_info" | grep -iq "amd"; then
    DETECT_AMD=true
fi
if echo "$gpu_info" | grep -iq "intel"; then
    DETECT_INTEL=true
fi

# 2. Bluetooth
if [ -d /sys/class/bluetooth ] || lsusb | grep -qi "bluetooth" 2>/dev/null; then
    DETECT_BLUETOOTH=true
fi

# 3. Batería (Laptop)
if [ -d /sys/class/power_supply ]; then
    for supply in /sys/class/power_supply/*; do
        if [ -f "$supply/type" ] && grep -qi "battery" "$supply/type"; then
            DETECT_BATTERY=true
            break
        fi
    done
fi

echo "Hardware detectado:"
[ "$DETECT_NVIDIA" = true ] && echo "- Tarjeta Gráfica NVIDIA"
[ "$DETECT_AMD" = true ] && echo "- Tarjeta Gráfica AMD"
[ "$DETECT_INTEL" = true ] && echo "- Tarjeta Gráfica Intel"
[ "$DETECT_BLUETOOTH" = true ] && echo "- Bluetooth"
[ "$DETECT_BATTERY" = true ] && echo "- Batería (Laptop)"

# Lista de drivers a instalar
PACKAGES_DRIVERS=()

if [ "$DETECT_NVIDIA" = true ]; then
    PACKAGES_DRIVERS+=(nvidia nvidia-utils)
    if [ "$INSTALL_GUI" = true ]; then
        PACKAGES_DRIVERS+=(nvidia-settings)
    fi
    if [ "$INSTALL_GAMES" = true ]; then
        PACKAGES_DRIVERS+=(lib32-nvidia-utils)
    fi
fi

if [ "$DETECT_AMD" = true ]; then
    PACKAGES_DRIVERS+=(xf86-video-amdgpu vulkan-radeon libva-mesa-driver)
    if [ "$INSTALL_GAMES" = true ]; then
        PACKAGES_DRIVERS+=(lib32-vulkan-radeon lib32-libva-mesa-driver)
    fi
fi

if [ "$DETECT_INTEL" = true ]; then
    PACKAGES_DRIVERS+=(intel-media-driver vulkan-intel)
    if [ "$INSTALL_GAMES" = true ]; then
        PACKAGES_DRIVERS+=(lib32-vulkan-intel)
    fi
fi

PACKAGES_DESKTOP=(
    uwsm
    alacritty
    packagekit-qt6
    swaync
    waybar
    swayosd
    kdeconnect
    sway
    rofi
    xcb-util-cursor
    xorg-xhost
    nss-mdns
    python-pyqt5
    breeze-icons
    gsfonts
    cantarell-fonts
    ttf-jetbrains-mono-nerd
    brightnessctl
    kwallet-pam
    kwalletmanager
    plasma-browser-integration
    hyprsunset
    network-manager-applet
    wine
    xdg-desktop-portal-hyprland
    xdg-desktop-portal-gtk
    cliphist
    pavucontrol
    libreoffice-fresh
    mpv
    vlc
    vlc-plugins-all
    sddm
    hyprland
    hyprwire
    hyprutils
    hyprpwcenter
    hyprpolkitagent
    hyprpaper
    hyprlock
    hyprlang
    hyprland-qt-support
    hypridle
    hyprgraphics
    hyprcursor
    swappy
    ark
    gsmartcontrol
    kio-admin
    firewalld-config
    nm-connection-editor
    dolphin
    partitionmanager
    blender
)

PACKAGES_JUEGOS=(
    mangohud
    lib32-mangohud
    steam
    lutris
)

PACKAGES_DEV=(
    clang
    rust-analyzer
    gopls
    uv
)


AUR_BASE=(
    blesh
    needrestart
    bash-complete-alias
    lazydocker
)

AUR_DESKTOP=(
    rofi-power-menu
    sugar-candy
    qt6ct-kde
    qt5ct-kde
    xwaylandvideobridge
    brave-browser
    brave-origin-bin
    libqalculate
    discord
    obsidian
    orca-slicer-bin
    pgadmin4-desktop-bin
    proton-pass-bin
    proton-authenticator-bin
    qalculate-gtk
    imhex
    sunshine-bin
)

AUR_JUEGOS=(
    bottles
    obs-vkcapture
    lib32-obs-vkcapture
)

# --- Preparación e Instalación ---

# Habilitar repositorio multilib si se seleccionaron juegos
if [ "$INSTALL_GAMES" = true ]; then
    if ! grep -q "^\[multilib\]" /etc/pacman.conf; then
        echo "Habilitando repositorio multilib en /etc/pacman.conf..."
        sudo sed -i '/#\[multilib\]/,/#Include = \/etc\/pacman.d\/mirrorlist/ s/#//' /etc/pacman.conf
        sudo pacman -Sy
    fi
fi

# Construir lista de paquetes de pacman a instalar
TO_INSTALL=("${PACKAGES_BASE[@]}" "${PACKAGES_DEV[@]}")
if [ "$INSTALL_GUI" = true ]; then
    TO_INSTALL+=("${PACKAGES_DESKTOP[@]}")
fi
if [ "$INSTALL_GAMES" = true ]; then
    TO_INSTALL+=("${PACKAGES_JUEGOS[@]}")
fi

# Agregar drivers detectados
TO_INSTALL+=("${PACKAGES_DRIVERS[@]}")

# Agregar soporte de Bluetooth si se detectó
if [ "$DETECT_BLUETOOTH" = true ]; then
    TO_INSTALL+=(bluez bluez-utils)
    if [ "$INSTALL_GUI" = true ]; then
        TO_INSTALL+=(blueman)
    fi
fi

# Agregar soporte de batería si se detectó
if [ "$DETECT_BATTERY" = true ]; then
    TO_INSTALL+=(power-profiles-daemon)
fi

# Instalar paquetes oficiales
sudo pacman -S --needed --noconfirm "${TO_INSTALL[@]}"

# Configurar Tailscale
sudo tailscale set --operator=$USER
if [ "$INSTALL_GUI" = true ]; then
    tailscale configure systray --enable-startup systemd
fi

# Permisos y grupos
sudo groupadd -f docker
sudo groupadd -f input
sudo gpasswd -a $USER input
sudo gpasswd -a $USER docker

# Configuración gráfica básica
if [ "$INSTALL_GUI" = true ]; then
    xhost +local:root
fi



# Instalar paru si no está presente
if ! command -v paru &> /dev/null; then
    echo "Instalando paru (AUR helper)..."
    rm -rf /tmp/paru-bin
    git clone https://aur.archlinux.org/paru-bin.git /tmp/paru-bin
    (cd /tmp/paru-bin && makepkg -si --noconfirm)
    rm -rf /tmp/paru-bin
else
    echo "paru ya está instalado."
fi

# Construir lista de paquetes de AUR a instalar
AUR_TO_INSTALL=("${AUR_BASE[@]}")
if [ "$INSTALL_GUI" = true ]; then
    AUR_TO_INSTALL+=("${AUR_DESKTOP[@]}")
fi
if [ "$INSTALL_GAMES" = true ]; then
    AUR_TO_INSTALL+=("${AUR_JUEGOS[@]}")
fi

# Instalar paquetes AUR
if [ ${#AUR_TO_INSTALL[@]} -gt 0 ]; then
    paru -Syu --noconfirm --answerclean All --answerdiff None "${AUR_TO_INSTALL[@]}"
fi

if [ -d "$HOME/.cfg" ]; then
    echo "Repo bare existente en $HOME/dotfiles — no se clonara."
else
    git clone https://github.com/Billones142/dotfiles $HOME/dotfiles
fi

# Instalar Flatpaks si corresponde
if [ "$INSTALL_GUI" = true ]; then
    flatpak install -y \
        com.orcaslicer.OrcaSlicer \
        com.github.iwalton3.jellyfin-media-player
fi

# Configurar tema sugar-candy en SDDM
if [ "$INSTALL_GUI" = true ]; then
    echo "Habilitando tema sugar-candy en SDDM..."
    sudo mkdir -p /etc/sddm.conf.d
    sudo tee /etc/sddm.conf.d/theme.conf > /dev/null << 'EOF'
[Theme]
Current=sugar-candy
EOF

    THEME_CONF="/usr/share/sddm/themes/sugar-candy/theme.conf"
    if [ -f "$THEME_CONF" ]; then
        echo "Configurando parámetros de contraseña para sugar-candy..."
        # Configurar echoMode="Password"
        if grep -q "^echoMode=" "$THEME_CONF"; then
            sudo sed -i 's/^echoMode=.*/echoMode="Password"/' "$THEME_CONF"
        else
            echo 'echoMode="Password"' | sudo tee -a "$THEME_CONF" > /dev/null
        fi

        # Configurar passwordMaskDelay=0
        if grep -q "^passwordMaskDelay=" "$THEME_CONF"; then
            sudo sed -i 's/^passwordMaskDelay=.*/passwordMaskDelay=0/' "$THEME_CONF"
        else
            echo 'passwordMaskDelay=0' | sudo tee -a "$THEME_CONF" > /dev/null
        fi
    fi
fi

# servicios del sistema
SYSTEM_SERVICES_ENABLE=(
    firewalld.service
    opensnitchd.service
    avahi-daemon
    docker.socket
)

if [ "$DETECT_BLUETOOTH" = true ]; then
    SYSTEM_SERVICES_ENABLE+=(bluetooth.service)
fi

if [ "$DETECT_BATTERY" = true ]; then
    SYSTEM_SERVICES_ENABLE+=(power-profiles-daemon.service)
fi

sudo systemctl daemon-reload
sudo systemctl enable --now "${SYSTEM_SERVICES_ENABLE[@]}"

sudo systemctl disable --now \
    docker.service

# servicios de usuario y gráficos
systemctl --user daemon-reload

USER_SERVICES=()
if [ "$INSTALL_GUI" = true ]; then
    USER_SERVICES+=(
        tailscale-systray.service
        hyprpolkitagent.service
        swaync.service.service
        hypridle.service
        hyprpaper.service
        waybar.service
    )
    if [ "$DETECT_BLUETOOTH" = true ]; then
        USER_SERVICES+=(blueman-applet.service)
    fi
    if [ "$INSTALL_GAMES" = true ]; then
        USER_SERVICES+=(sunshine.service)
    fi
fi

if [ ${#USER_SERVICES[@]} -gt 0 ]; then
    systemctl --user enable --now "${USER_SERVICES[@]}"
fi

# ------------- FIREWALL -------------
# Configurar resolución mDNS en /etc/nsswitch.conf
if [ -f /etc/nsswitch.conf ]; then
    if ! grep -q "mdns_minimal" /etc/nsswitch.conf; then
        echo "Configurando resolución mDNS en /etc/nsswitch.conf..."
        if grep -q "resolve" /etc/nsswitch.conf; then
            sudo sed -i 's/^hosts:\(.*\)resolve/hosts:\1mdns_minimal [NOTFOUND=return] resolve/' /etc/nsswitch.conf
        else
            sudo sed -i 's/^hosts:\(.*\)/hosts:\1 mdns_minimal [NOTFOUND=return]/' /etc/nsswitch.conf
        fi
    fi
fi
sudo firewall-cmd --add-service=mdns --permanent
if [ "$INSTALL_GUI" = true ]; then
    sudo firewall-cmd --add-service=kdeconnect --permanent
fi
sudo firewall-cmd --reload

# Configurar KWallet en PAM para SDDM (al final de las secciones auth y session respectivamente)
if [ "$INSTALL_GUI" = true ] && [ -f /etc/pam.d/sddm ]; then
    echo "Configurando KWallet en /etc/pam.d/sddm..."
    sudo python3 -c '
import sys
pam_file = "/etc/pam.d/sddm"
try:
    with open(pam_file, "r") as f:
        lines = f.readlines()
except Exception as e:
    print(f"Error leyendo {pam_file}: {e}")
    sys.exit(1)

content = "".join(lines)
if "pam_kwallet5.so" in content:
    print("pam_kwallet5.so ya está configurado en /etc/pam.d/sddm.")
    sys.exit(0)

last_auth_idx = -1
last_session_idx = -1
for i, line in enumerate(lines):
    parts = line.strip().split()
    if not parts or parts[0].startswith("#"):
        continue
    pam_type = parts[0].lstrip("-")
    if pam_type == "auth":
        last_auth_idx = i
    elif pam_type == "session":
        last_session_idx = i

insertions = []
if last_auth_idx != -1:
    insertions.append((last_auth_idx + 1, "auth       optional    pam_kwallet5.so\n"))
if last_session_idx != -1:
    insertions.append((last_session_idx + 1, "session     optional    pam_kwallet5.so         auto_start\n"))

insertions.sort(key=lambda x: x[0], reverse=True)
for idx, text in insertions:
    lines.insert(idx, text)

try:
    with open(pam_file, "w") as f:
        f.writelines(lines)
    print("pam_kwallet5.so configurado correctamente.")
except Exception as e:
    print(f"Error escribiendo {pam_file}: {e}")
    sys.exit(1)
'
fi

sudo mkdir -p \
    /media/$USER/truenas-share \
    /media/$USER/truenas-stefano \
    /media/$USER/cloud/gdrive \

sudo chown -R u=rwx,g=,o= $USER:$USER \
    /media/$USER/

# Aplicar las configuraciones con stow (al final del script)
if [ -d "$HOME/dotfiles" ]; then
    echo "Aplicando configuraciones con GNU Stow..."
    (
        cd "$HOME/dotfiles" || exit 1
        for pkg in *; do
            if [ -d "$pkg" ] && [ "$pkg" != ".git" ]; then
                echo "Procesando paquete: $pkg"
                # Buscar y resolver conflictos de archivos existentes
                find "$pkg" -type f | while read -r file; do
                    rel_path="${file#$pkg/}"
                    target="$HOME/$rel_path"
                    
                    if [ -e "$target" ] || [ -L "$target" ]; then
                        # Si ya es el enlace correcto, no hacer nada
                        if [ -L "$target" ] && [ "$(readlink -f "$target")" = "$(readlink -f "$file")" ]; then
                            continue
                        fi
                        
                        read -p "Conflicto: ~/$rel_path ya existe. ¿Desea reemplazarlo con el archivo de tus dotfiles? (Se respaldará a .bak) [s/N]: " ans
                        if [[ "$ans" =~ ^[SsYy]$ ]]; then
                            echo "Respaldando ~/$rel_path a ~/$rel_path.bak..."
                            mv "$target" "$target.bak"
                        else
                            echo "Conservando ~/$rel_path original."
                        fi
                    fi
                done
                
                # Ejecutar stow para crear los enlaces
                stow --dir="$HOME/dotfiles" --target="$HOME" "$pkg"
            fi
        done
    )
fi

echo "Recomendado reiniciar la terminal"
