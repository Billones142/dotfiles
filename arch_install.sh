#!/bin/bash
#TODO: no borrar hasta terminar
exit 0

# pide los permisos de sudo
sudo -v

# Mantener el sudo "vivo" en segundo plano
# Esto corre un bucle que actualiza el timeout cada 60 segundos
# hasta que el script principal termine.
( while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null & )

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

sudo pacman -Sy --noconfirm archlinux-keyring
sudo pacman -Syu --noconfirm

sudo pacman -S --needed --noconfirm base-devel git
git config --global core.pager 'moor'
#TODO: habilitar colores en git

# necesario
sudo pacman -S --noconfirm \
    uwsm \
    alacritty \
    nmap \
    swaync \
    waybar \
    swayosd \
    kdeconnect \
    sway \
    flatpak \
    firewalld \
    stow \
    tailscale \
    htop \
    nvtop \
    rofi \
    xcb-util-cursor \
    xorg-xhost \
    nss-mdns \
    wget \
    python-reportlab \
    python-pyqt5 \
    breeze-icons \
    qt5ct \
    qt6ct \
    gsfonts \
    cantarell-fonts \
    ttf-jetbrains-mono-nerd \
    brightnessctl \
    kwallet-pam \
    kwalletmanager \
    plasma-browser-integration \
    hyprsunset \
    network-manager-applet \
    wine \
    moor \
    less \
    xdg-desktop-portal-hyprland \
    xdg-desktop-portal-gtk \
    cliphist \
    fuse2 \
    pavucontrol \
    libreoffice-fresh \
    github-cli \
    mpv \
    vlc \
    vlc-plugins-all \
    syncthing \
    sddm \
    hyprland \
    hyprwire \
    hyprutils \
    hyprpwcenter \
    hyprpolkitagent \
    hyprpaper \
    hyprlock \
    hyprlang \
    hyprland-qt-support \
    hypridle \
    hyprgraphics \
    hyprcursor \
    xdg-desktop-portal-hyprland \
    swappy \

# TODO: agregar pam_kwallet.so en /etc/pam.d/sddm

sudo tailscale set --operator=$USER
tailscale configure systray --enable-startup systemd

#TODO: configurar kwallet pam, sudo nvim /etc/pam.d/login

# solo laptop
sudo pacman -S --noconfirm \
    swayosd

xhost +local:root

sudo groupadd -f docker
sudo groupadd -f input

sudo gpasswd -a $USER input
sudo gpasswd -a $USER docker

# GUI
sudo pacman -S --noconfirm \
    firewalld-config \
    nm-connection-editor \
    sddm \
    dolphin \
    partitionmanager \

#TODO: si tiene bluetooth
#bluez bluez-utils blueman

#TODO: bateria
# power-profiles-daemon
# sudo systemctl enable --now power-profiles-daemon.service


# Otros
sudo pacman -S --noconfirm \
    docker \
    blender \

# Instalando yay si no esta instalado
if ! yay --version > /dev/null 2>&1; then
    # Si el comando falla (exit code != 0), ejecutamos la reparación
    fix_yay
else
    echo "👌 Yay está operativo."
fi


# programas yay
yay -Syu --noconfirm --answerclean All --answerdiff None \
    rofi-power-menu \
    blesh \
    sugar-candy \
    needrestart \

# otros
yay -S --noconfirm --answerclean All --answerdiff None \
    brave-browser \
    lazydocker \
    libqalculate \
    discord \
    obsidian \
    orca-slicer-bin \
    pgadmin4-desktop-bin
    proton-pass-bin \
    proton-authenticator-bin \
    bottles

if [ -d "$HOME/.cfg" ]; then
    echo "Repo bare existente en $HOME/dotfiles — no se clonara."
else
    git clone https://github.com/Billones142/dotfiles $HOME/dotfiles
fi

flatpak install -y com.orcaslicer.OrcaSlicer com.github.iwalton3.jellyfin-media-player

# firewall
#

# modo oscuro
#TODO: agregar cambios a qt5/6
gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita-dark'

#TODO: 
#/usr/lib/sddm/sddm.conf.d/default.conf
#Current=sugar-candy
# habilitar sugar-candy en sddm, /usr/share/sddm/themes/sugar-candy
# echoMode: TextInput.Password
# passwordMaskDelay: 0

sudo systemctl daemon-reload

# servicios del sistema
sudo systemctl enable --now \
    firewalld
    avahi-daemon
    docker.socket

# servicios de usuario
systemctl --user daemon-reload

systemctl --user enable --now \
    tailscale-systray \
    hyprpolkitagent \
    blueman-applet \
    swaync \
    hypridle \
    hyprpaper \
    waybar \

#TODO: activar servicio de detecion de mdns
# hosts: mymachines **mdns_minimal [NOTFOUND=return]** resolve [!UNAVAIL=return] files myhostname dns
#sudo nvim /etc/nsswitch.conf
sudo firewall-cmd --add-service=mdns --permanent
sudo firewall-cmd --reload


# TODO: crear wallet de kwallet y habilitar servicio para activacion

sudo mkdir -p /media/$USER/truenas-share /media/$USER/truenas-stefano
sudo chown -R $USER:$USER /media/stefano/
chmod -R u=rwx,g=,o= /media/stefano/
