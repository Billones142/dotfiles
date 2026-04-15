#!/bin/bash
#TODO: no borrar hasta terminar
exit 0
sudo pacman -S --needed base-devel git
#TODO: habilitar colores en git

# necesario
sudo pacman -S nmap swaync swayosd kdeconnect sway flatpak firewalld stow tailscale htop nvtop rofi xcb-util-cursor xorg-xhost nss-mdns wget python-reportlab python-pyqt5 breeze-icons qt5ct qt6ct gsfonts cantarell-fonts ttf-jetbrains-mono-nerd brightnessctl kwallet-pam kwalletmanager plasma-browser-integration

sudo tailscale set --operator=$USER

#TODO: configurar kwallet pam, sudo nvim /etc/pam.d/login

xhost +local:root
sudo gpasswd -a $USER input

# GUI
sudo pacman -S firewalld-config firewalld-applet nm-connection-editor sddm dolphin partitionmanager

#TODO: si tiene bluetooth
#bluez bluez-utils blueman


# Otros
sudo pacman -S docker

sudo pacman -S --needed base-devel git


yay -S rofi-power-menu brave-browser blesh sugar-candy obsidian

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

#TODO: habilitar sugar-candy en sddm, /usr/share/sddm/themes/sugar-candy
# echoMode: TextInput.Password
# passwordMaskDelay: 0

sudo systemctl enable --now firewalld
sudo systemctl enable --now avahi-daemon

systemctl --user enable --now hyprpolkitagent
systemctl --user enable --now blueman-applet

#TODO: activar servicio de detecion de mdns
# hosts: mymachines **mdns_minimal [NOTFOUND=return]** resolve [!UNAVAIL=return] files myhostname dns
#sudo nvim /etc/nsswitch.conf
sudo firewall-cmd --add-service=mdns --permanent
sudo firewall-cmd --reload
