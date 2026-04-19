#!/bin/bash
#TODO: no borrar hasta terminar
exit 0
sudo pacman -Syu

sudo pacman -S --needed base-devel git
git config --global core.pager 'moor'
#TODO: habilitar colores en git

# necesario
sudo pacman -S \
    nmap \
    swaync \
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
    libreoffice \
    github-cli \
    mpv \
    vlc \
    vlc-plugins-all \

# TODO: agregar pam_kwallet.so en /etc/pam.d/sddm

sudo tailscale set --operator=$USER
tailscale configure systray --enable-startup systemd

#TODO: configurar kwallet pam, sudo nvim /etc/pam.d/login

# solo laptop
sudo pacman -S \
    swayosd

xhost +local:root

sudo groupadd -f docker
sudo groupadd -f input

sudo gpasswd -a $USER input
sudo gpasswd -a $USER docker

# GUI
sudo pacman -S \
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
sudo pacman -S \
    docker \
    blender \

# programas yay
yay -Syu \
    rofi-power-menu \
    blesh \
    sugar-candy \
    needrestart \

# otros
yay -S \
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

flatpak install com.orcaslicer.OrcaSlicer com.github.iwalton3.jellyfin-media-player

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

#TODO: activar servicio de detecion de mdns
# hosts: mymachines **mdns_minimal [NOTFOUND=return]** resolve [!UNAVAIL=return] files myhostname dns
#sudo nvim /etc/nsswitch.conf
sudo firewall-cmd --add-service=mdns --permanent
sudo firewall-cmd --reload

sudo mkdir -p /media/$USER/truenas-share /media/$USER/truenas-stefano
sudo chown -R $USER:$USER /media/stefano/
chmod -R u=rwx,g=,o= /media/stefano/
