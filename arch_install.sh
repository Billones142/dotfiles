#!/bin/bash
#TODO: no borrar hasta terminar
exit 0

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
#TODO: habilitar colores en git

# necesario
sudo pacman -S --needed --noconfirm \
    uwsm \
    alacritty \
    #packagekit-qt6 \ # No recomendado al usar Discover
    #archlinux-appstream-data \
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
    #qt5ct \  # remplazado por qt5ct-kde para compatibilidad con kde
    #qt6ct \ # remplazado por qt6ct-kde para compatibilidad con kde
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
    ark \
    arj \
    lrzip \
    lzop \
    7zip \
    unarchiver \
    unrar \
    gsmartcontrol \
    kio-admin \

# servidor de lenguaje
sudo pacman -S --noconfirm \
    clang \
    rust-analyzer \
    gopls \

# TODO: agregar pam_kwallet.so en /etc/pam.d/sddm

sudo tailscale set --operator=$USER
tailscale configure systray --enable-startup systemd


# solo laptop
sudo pacman -S --noconfirm \
    swayosd \

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
    mangohud \
    lib32-mangohud \

#TODO: si tiene bluetooth
#bluez bluez-utils blueman

#TODO: bateria
# power-profiles-daemon
# sudo systemctl enable --now power-profiles-daemon.service


# Otros
sudo pacman -S --noconfirm \
    docker \
    blender \

# TODO: instalar o reparar paru

# programas AUR
paru -Syu --noconfirm --answerclean All --answerdiff None \
    rofi-power-menu \
    blesh \
    sugar-candy \
    needrestart \
    qt6ct-kde \
    qt5ct-kde \
    xwaylandvideobridge \
    bash-complete-alias \

# otros
paru -S --noconfirm --answerclean All --answerdiff None \
    brave-browser \
    brave-origin-bin \
    lazydocker \
    libqalculate \
    discord \
    obsidian \
    orca-slicer-bin \
    pgadmin4-desktop-bin
    proton-pass-bin \
    proton-authenticator-bin \
    bottles \
    qalculate-gtk \
    imhex \
    sunshine-bin \
    obs-vkcapture \
    lib32-obs-vkcapture \

if [ -d "$HOME/.cfg" ]; then
    echo "Repo bare existente en $HOME/dotfiles — no se clonara."
else
    git clone https://github.com/Billones142/dotfiles $HOME/dotfiles
    #TODO: Aplicar las configuraciones con stow
fi

flatpak install -y \
	com.orcaslicer.OrcaSlicer \
	com.github.iwalton3.jellyfin-media-player \

#TODO: 
#/usr/lib/sddm/sddm.conf.d/default.conf
#Current=sugar-candy
# habilitar sugar-candy en sddm, /usr/share/sddm/themes/sugar-candy
# echoMode: TextInput.Password
# passwordMaskDelay: 0


# servicios del sistema
sudo systemctl daemon-reload
sudo systemctl enable --now \
    firewalld.service \
    opensnitchd.service \
    avahi-daemon \
    docker.socket \
    opensnitchd.service \

sudo systemctl disable --now \
    docker.service

# servicios de usuario
systemctl --user daemon-reload
systemctl --user enable --now \
    tailscale-systray.service \
    hyprpolkitagent.service \
    blueman-applet.service \
    swaync.service.service \
    hypridle.service \
    hyprpaper.service \
    waybar.service \
    sunshine.service \

# ------------- FIREWALL -------------
#TODO: activar servicio de detecion de mdns
# hosts: mymachines **mdns_minimal [NOTFOUND=return]** resolve [!UNAVAIL=return] files myhostname dns
#sudo nvim /etc/nsswitch.conf
sudo firewall-cmd --add-service=mdns --permanent
sudo firewall-cmd --add-service=kdeconnect --permanent
sudo firewall-cmd --reload


# TODO: crear wallet de kwallet y habilitar servicio para activacion
# /etc/pam.d/sddm: agregar 
# -auth       optional    pam_kwallet5.so
# session     optional    pam_kwallet5.so         auto_start

sudo mkdir -p \
    /media/$USER/truenas-share \
    /media/$USER/truenas-stefano \
    /media/$USER/cloud/gdrive \

sudo chown -R u=rwx,g=,o= $USER:$USER \
    /media/$USER/

echo "Recomendado reiniciar la terminal"
